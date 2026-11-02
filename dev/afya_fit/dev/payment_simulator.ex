defmodule AfyaFit.Dev.PaymentSimulator do
  @moduledoc """
  Stands in for Paystack and Daraja while developing, so the whole payment flow
  can be tried without credentials or a public callback URL. It is used when
  `PAYSTACK_SECRET_KEY` / `DARAJA_CONSUMER_KEY` are not set (see `config/runtime.exs`);
  setting them switches that provider to the real thing.

    * **Card.** Checkout sends you to a local page (`/dev/pay/:reference`) with
      Pay and Fail buttons, then back to Billing, which asks the simulator what
      happened exactly as it would ask Paystack.
    * **M-Pesa.** The "phone prompt" is answered after a few seconds by calling
      the real callback handler, as Safaricom would. A number ending in `0` is
      cancelled; any other is paid.

  What each simulated payment decided is kept in memory for this node only. It is
  compiled in development and test, so it cannot ship.
  """

  @doc "How long the simulated phone takes to answer, in milliseconds."
  def delay_ms, do: Application.get_env(:afya_fit, :sim_delay_ms, 3_000)

  @doc "Remember what happened to a simulated payment: `{:card, reference}` or `{:stk, checkout_id}`."
  def put(key, outcome), do: :persistent_term.put({__MODULE__, key}, outcome)

  @doc "What was decided, or `nil` while nobody has answered."
  def get(key), do: :persistent_term.get({__MODULE__, key}, nil)
end

defmodule AfyaFit.Dev.SimulatedPaystack do
  @moduledoc "Paystack for development: see `AfyaFit.Dev.PaymentSimulator`."

  alias AfyaFit.Billing.Payment
  alias AfyaFit.Dev.PaymentSimulator
  alias AfyaFit.Repo

  def enabled?, do: true

  # The "hosted checkout" is a page of our own on the same host as the app.
  def checkout(_email, _amount, reference, _metadata, callback_url) do
    uri = URI.parse(callback_url)
    {:ok, URI.to_string(%{uri | path: "/dev/pay/#{reference}", query: nil})}
  end

  def verify(reference) do
    payment = Repo.get_by(Payment, reference: reference)

    case {payment, PaymentSimulator.get({:card, reference})} do
      {%Payment{} = p, :success} ->
        {:ok, %{status: "success", amount: p.amount, currency: p.currency}}

      {%Payment{} = p, :failed} ->
        {:ok, %{status: "failed", amount: p.amount, currency: p.currency}}

      _undecided ->
        {:ok, %{status: "abandoned", amount: Decimal.new(0), currency: "KES"}}
    end
  end
end

defmodule AfyaFit.Dev.SimulatedMpesa do
  @moduledoc "Daraja for development: see `AfyaFit.Dev.PaymentSimulator`."

  alias AfyaFit.Billing.MpesaCallback
  alias AfyaFit.Dev.PaymentSimulator
  alias AfyaFit.Payments.Daraja

  defdelegate normalize_phone(phone), to: Daraja

  def enabled?, do: true

  def stk_push(%{phone: phone, amount: amount, reference: reference, callback_url: callback_url}) do
    checkout_id = "ws_SIM_" <> reference
    token = callback_url |> String.split("/") |> List.last()
    outcome = if String.ends_with?(phone, "0"), do: :cancelled, else: :paid

    {:ok, _pid} =
      Task.start(fn ->
        Process.sleep(PaymentSimulator.delay_ms())
        PaymentSimulator.put({:stk, checkout_id}, outcome)

        AfyaFit.RLS.unscoped(fn ->
          MpesaCallback.handle(token, callback(checkout_id, outcome, amount, phone))
        end)
      end)

    {:ok, %{checkout_request_id: checkout_id, merchant_request_id: "mr_sim_" <> reference}}
  end

  def stk_query(checkout_id) do
    case PaymentSimulator.get({:stk, checkout_id}) do
      :paid -> {:ok, %{result_code: 0, description: "Simulated: paid"}}
      :cancelled -> {:ok, %{result_code: 1032, description: "Simulated: cancelled by user"}}
      nil -> {:ok, %{result_code: nil, description: nil}}
    end
  end

  defp callback(checkout_id, :paid, amount, phone) do
    stk(checkout_id, 0, "The service request is processed successfully.", [
      %{"Name" => "Amount", "Value" => amount},
      %{
        "Name" => "MpesaReceiptNumber",
        "Value" => "SIM" <> Integer.to_string(:erlang.phash2(checkout_id))
      },
      %{"Name" => "PhoneNumber", "Value" => String.to_integer(phone)}
    ])
  end

  defp callback(checkout_id, :cancelled, _amount, _phone),
    do: stk(checkout_id, 1032, "Request cancelled by user", nil)

  defp stk(checkout_id, code, description, items) do
    callback = %{
      "MerchantRequestID" => "mr_sim",
      "CheckoutRequestID" => checkout_id,
      "ResultCode" => code,
      "ResultDesc" => description
    }

    callback =
      if items, do: Map.put(callback, "CallbackMetadata", %{"Item" => items}), else: callback

    %{"Body" => %{"stkCallback" => callback}}
  end
end
