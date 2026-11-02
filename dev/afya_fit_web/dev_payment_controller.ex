defmodule AfyaFitWeb.DevPaymentController do
  @moduledoc """
  The stand-in for Paystack's hosted checkout page in development
  (`AfyaFit.Dev.SimulatedPaystack`). Only routed when `:dev_routes` is on.
  """
  use AfyaFitWeb, :controller

  alias AfyaFit.Billing.{Payment, Plans}
  alias AfyaFit.Dev.PaymentSimulator
  alias AfyaFit.Repo

  def show(conn, %{"reference" => reference}) do
    case Repo.get_by(Payment, reference: reference) do
      nil -> conn |> put_status(:not_found) |> text("No such payment.")
      payment -> html(conn, page(payment, get_csrf_token()))
    end
  end

  def decide(conn, %{"reference" => reference, "outcome" => outcome}) do
    PaymentSimulator.put(
      {:card, reference},
      if(outcome == "success", do: :success, else: :failed)
    )

    redirect(conn, to: ~p"/billing?reference=#{reference}")
  end

  defp page(payment, csrf) do
    action = "/dev/pay/#{payment.reference}"

    """
    <!doctype html>
    <meta charset="utf-8">
    <title>Simulated Paystack</title>
    <body style="font-family:system-ui;max-width:28rem;margin:4rem auto;padding:0 1rem">
      <p style="color:#a60">Development only: this stands in for Paystack. No money moves.</p>
      <h1>Pay #{Plans.format(payment.amount)}</h1>
      <p>#{String.capitalize(payment.plan_type)} plan, reference #{payment.reference}</p>
      <form method="post" action="#{action}/success" style="display:inline">
        <input type="hidden" name="_csrf_token" value="#{csrf}">
        <button id="pay" style="padding:.6rem 1.2rem">Pay</button>
      </form>
      <form method="post" action="#{action}/fail" style="display:inline">
        <input type="hidden" name="_csrf_token" value="#{csrf}">
        <button id="fail" style="padding:.6rem 1.2rem">Fail</button>
      </form>
    </body>
    """
  end
end
