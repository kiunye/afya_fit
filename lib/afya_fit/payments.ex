defmodule AfyaFit.Payments do
  @moduledoc """
  The payment gateways checkout talks to, so tests can swap in fakes:

      config :afya_fit, paystack_gateway: MyFake, mpesa_gateway: MyFake

  Every gateway answers `enabled?/0` (are its credentials set?). The Paystack
  gateway also needs `checkout/5` and `verify/1`; the M-Pesa gateway needs
  `stk_push/1`, `stk_query/1` and `normalize_phone/1`. See
  `AfyaFit.Payments.PaystackClient` and `AfyaFit.Payments.Daraja`.
  """

  alias AfyaFit.Payments.{Daraja, PaystackClient}

  def paystack, do: Application.get_env(:afya_fit, :paystack_gateway, PaystackClient)
  def mpesa, do: Application.get_env(:afya_fit, :mpesa_gateway, Daraja)

  @doc "Whether card payments (Paystack) can be offered."
  def paystack_enabled?, do: paystack().enabled?()

  @doc "Whether M-Pesa can be offered."
  def mpesa_enabled?, do: mpesa().enabled?()
end
