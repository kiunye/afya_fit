defmodule AfyaFitWeb.API.AdminController do
  use AfyaFitWeb, :controller

  alias AfyaFit.{Accounts, Billing, Clients, Organizations}

  # Authentication is handled in router pipeline
  # Admin role check should be in router pipeline

  action_fallback AfyaFitWeb.API.FallbackController

  @doc """
  Get all trainers in the organization.
  """
  def trainers(conn, _params) do
    current_user = conn.assigns.current_user

    trainers =
      Accounts.list_organization_users(current_user.organization_id, "trainer")

    json(conn, %{data: Enum.map(trainers, &format_user/1)})
  end

  @doc """
  Get all clients subscribed to the organization.
  """
  def clients(conn, _params) do
    current_user = conn.assigns.current_user

    clients =
      Clients.list_organization_clients(current_user.organization_id, %{})

    json(conn, %{data: Enum.map(clients, &format_user/1)})
  end

  @doc """
  Get organization subscription.
  """
  def subscription(conn, _params) do
    current_user = conn.assigns.current_user

    subscription =
      Billing.get_subscription_by_organization(current_user.organization_id)

    case subscription do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "No subscription found"})

      subscription ->
        json(conn, %{data: format_subscription(subscription)})
    end
  end

  defp format_user(user) do
    %{
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      role: user.role,
      phone: user.phone,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end

  defp format_subscription(subscription) do
    %{
      id: subscription.id,
      organization_id: subscription.organization_id,
      plan_type: subscription.plan_type,
      status: subscription.status,
      current_period_start: subscription.current_period_start,
      current_period_end: subscription.current_period_end,
      cancel_at_period_end: subscription.cancel_at_period_end,
      cancelled_at: subscription.cancelled_at,
      inserted_at: subscription.inserted_at,
      updated_at: subscription.updated_at
    }
  end
end
