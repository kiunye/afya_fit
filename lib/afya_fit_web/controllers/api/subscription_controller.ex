defmodule AfyaFitWeb.API.SubscriptionController do
  use AfyaFitWeb, :controller

  alias AfyaFit.{Billing, Organizations}

  # Authentication is handled in router pipeline

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

  def create(conn, %{"subscription" => subscription_params}) do
    current_user = conn.assigns.current_user

    # Load organization
    organization = Organizations.get_organization!(current_user.organization_id)

    plan_type = Map.get(subscription_params, "plan_type", "pro")
    customer_email = Map.get(subscription_params, "email", current_user.email)
    customer_name = "#{current_user.first_name} #{current_user.last_name}"

    case Billing.create_subscription(organization, plan_type, customer_email, customer_name) do
      {:ok, subscription} ->
        conn
        |> put_status(:created)
        |> json(%{
          data: %{
            id: subscription.id,
            plan_type: subscription.plan_type,
            status: subscription.status
          }
        })

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"422", changeset: format_error(error))
    end
  end

  def update(conn, %{"subscription" => subscription_params}) do
    current_user = conn.assigns.current_user

    case Billing.get_subscription_by_organization(current_user.organization_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"404")

      subscription ->
        # For now, only allow updating plan_type
        # In production, you'd want to handle plan upgrades/downgrades properly
        attrs = Map.take(subscription_params, ["plan_type"])

        case Billing.update_subscription(subscription, attrs) do
          {:ok, subscription} ->
            json(conn, %{
              data: %{
                id: subscription.id,
                plan_type: subscription.plan_type,
                status: subscription.status
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

  defp format_error(%Ecto.Changeset{} = changeset), do: changeset
  defp format_error(message) when is_binary(message), do: %{errors: [message]}
  defp format_error(error), do: %{errors: [inspect(error)]}
end
