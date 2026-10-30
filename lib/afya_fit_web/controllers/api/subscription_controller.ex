defmodule AfyaFitWeb.API.SubscriptionController do
  use AfyaFitWeb, :controller

  alias AfyaFit.Billing

  # Authentication is handled in router pipeline.
  #
  # There is deliberately no way to create or change a plan here: a plan is
  # bought through checkout (AfyaFit.Billing.Checkout), never set by a request.

  plug AfyaFitWeb.API.AuthorizePlug,
    resource: :subscription,
    actions: %{show: :read, invoices: :read},
    default: :manage

  action_fallback AfyaFitWeb.API.FallbackController

  def show(conn, _params) do
    current_user = conn.assigns.current_user

    case Billing.get_subscription_by_organization(current_user.organization_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"404")

      subscription ->
        json(conn, %{
          data: %{
            id: subscription.id,
            plan_type: subscription.plan_type,
            status: subscription.status,
            current_period_start: subscription.current_period_start,
            current_period_end: subscription.current_period_end,
            cancel_at_period_end: subscription.cancel_at_period_end,
            cancelled_at: subscription.cancelled_at
          }
        })
    end
  end

  def cancel(conn, _params) do
    current_user = conn.assigns.current_user

    case Billing.get_subscription_by_organization(current_user.organization_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"404")

      subscription ->
        case Billing.cancel_subscription(subscription) do
          {:ok, subscription} ->
            json(conn, %{
              data: %{
                id: subscription.id,
                status: subscription.status,
                cancel_at_period_end: subscription.cancel_at_period_end
              }
            })

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(AfyaFitWeb.API.ErrorView)
            |> render(:"422", changeset: changeset)
        end
    end
  end

  def invoices(conn, _params) do
    current_user = conn.assigns.current_user

    case Billing.get_subscription_by_organization(current_user.organization_id) do
      nil ->
        json(conn, %{data: []})

      subscription ->
        invoices = Billing.list_invoices(subscription.id)

        json(conn, %{
          data:
            Enum.map(invoices, fn invoice ->
              %{
                id: invoice.id,
                invoice_number: invoice.invoice_number,
                amount: Decimal.to_float(invoice.amount),
                currency: invoice.currency,
                status: invoice.status,
                due_date: invoice.due_date,
                paid_at: invoice.paid_at
              }
            end)
        })
    end
  end
end
