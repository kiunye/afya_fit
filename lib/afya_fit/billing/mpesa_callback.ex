defmodule AfyaFit.Billing.MpesaCallback do
  @moduledoc """
  What to make of Daraja's callback for an STK push.

  Daraja does not sign callbacks, so nothing in one is believed on its own:
  the payment is found by the secret token in the callback URL, the checkout
  request id must match, the amount must cover the price, and a success is
  confirmed with an STK query before the payment settles. A failure is taken
  at its word, because at worst it fails a payment that nobody can pay now.
  """

  alias AfyaFit.Billing.{Checkout, Payment}
  alias AfyaFit.{Payments, Repo}
  alias AfyaFit.Payments.Daraja

  @doc """
  Handles a callback. Returns `:ok` whatever happens, because the answer to
  Daraja is always "accepted"; a refusal would only make it retry.
  """
  @spec handle(String.t(), map()) :: :ok
  def handle(token, %{"Body" => %{"stkCallback" => callback}}) when is_binary(token) do
    with %Payment{provider: "daraja", provider_reference: checkout_id} = payment <-
           Repo.get_by(Payment, callback_token: token),
         true <- checkout_id == callback["CheckoutRequestID"] do
      decide(payment, Daraja.result_code(callback["ResultCode"]), callback)
    end

    :ok
  end

  def handle(_token, _body), do: :ok

  defp decide(payment, 0, callback) do
    items = callback |> get_in(["CallbackMetadata", "Item"]) |> List.wrap()
    paid = items |> item("Amount") |> to_decimal()

    cond do
      is_nil(paid) or Decimal.compare(paid, payment.amount) == :lt ->
        Checkout.fail(payment, "amount did not match")

      confirmed?(payment) ->
        Checkout.settle(payment, %{
          receipt: item(items, "MpesaReceiptNumber"),
          provider_payload: %{"callback" => callback}
        })

      true ->
        # Daraja has not confirmed it (yet); the reconciler will look again.
        :unconfirmed
    end
  end

  defp decide(payment, _code, callback) do
    Checkout.fail(payment, callback["ResultDesc"] || "the payment was not completed")
  end

  defp confirmed?(payment) do
    match?({:ok, %{result_code: 0}}, Payments.mpesa().stk_query(payment.provider_reference))
  end

  defp item(items, name) do
    Enum.find_value(items, fn
      %{"Name" => ^name, "Value" => value} -> value
      _ -> nil
    end)
  end

  defp to_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value)

  defp to_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> decimal
      _ -> nil
    end
  end

  defp to_decimal(_value), do: nil
end
