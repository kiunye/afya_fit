defmodule AfyaFitWeb.MpesaWebhookController do
  @moduledoc """
  Daraja's callback for an STK push. Daraja does not sign callbacks, so the URL
  carries a secret token that only the payment and Safaricom know, and the
  result is confirmed with Daraja before a payment counts
  (`AfyaFit.Billing.Checkout.mpesa_callback/2`).

  Daraja is always answered "accepted": a refusal would only make it retry.
  """
  use AfyaFitWeb, :controller

  alias AfyaFit.Billing.Checkout

  def callback(conn, %{"token" => token} = params) do
    Checkout.mpesa_callback(token, Map.delete(params, "token"))

    json(conn, %{ResultCode: 0, ResultDesc: "Accepted"})
  end
end
