defmodule AfyaFit.Test.FakeGateways do
  @moduledoc """
  Stand-ins for Paystack and Daraja in tests. They answer straight away and
  remember what they were asked, so a test can also say what the provider will
  report later (`set_verify/2`, `set_query/2`). State is keyed by reference, so
  concurrent tests do not meet.
  """
  use Agent

  def start_link(_opts), do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  def put(key, value), do: Agent.update(__MODULE__, &Map.put(&1, key, value))
  def get(key, default \\ nil), do: Agent.get(__MODULE__, &Map.get(&1, key, default))

  @doc "What Paystack will say when asked about `reference`."
  def set_verify(reference, result), do: put({:verify, reference}, result)

  @doc "What Daraja will say when asked about `checkout_request_id`."
  def set_query(checkout_request_id, result), do: put({:query, checkout_request_id}, result)

  @doc "What was sent to the gateway for `reference`, if anything."
  def sent(reference), do: get({:sent, reference})
end

defmodule AfyaFit.Test.FakePaystack do
  @moduledoc false
  alias AfyaFit.Test.FakeGateways

  def checkout("gateway-down@example.com", _amount, _reference, _metadata, _callback),
    do: {:error, "Paystack is down"}

  def checkout(email, amount, reference, metadata, callback_url) do
    FakeGateways.put(
      {:sent, reference},
      %{email: email, amount: amount, metadata: metadata, callback_url: callback_url}
    )

    {:ok, "https://checkout.paystack.test/" <> reference}
  end

  def verify(reference) do
    FakeGateways.get(
      {:verify, reference},
      {:ok, %{status: "abandoned", amount: Decimal.new(0), currency: "KES"}}
    )
  end
end

defmodule AfyaFit.Test.FakeMpesa do
  @moduledoc false
  alias AfyaFit.Payments.Daraja
  alias AfyaFit.Test.FakeGateways

  defdelegate normalize_phone(phone), to: Daraja

  def stk_push(%{phone: "254799999999"}), do: {:error, "Daraja is down"}

  def stk_push(%{reference: reference} = request) do
    FakeGateways.put({:sent, reference}, request)
    {:ok, %{checkout_request_id: "ws_CO_" <> reference, merchant_request_id: "mr_" <> reference}}
  end

  def stk_query(checkout_request_id) do
    FakeGateways.get({:query, checkout_request_id}, {:ok, %{result_code: nil, description: nil}})
  end
end
