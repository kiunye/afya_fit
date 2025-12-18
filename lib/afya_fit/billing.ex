defmodule AfyaFit.Billing do
  @moduledoc """
  The Billing context.
  """
  import Ecto.Query, warn: false
  alias AfyaFit.Billing.{Invoice, Subscription}
  alias AfyaFit.Repo

  def get_subscription_by_organization(organization_id) do
    Repo.get_by(Subscription, organization_id: organization_id)
  end

  def create_subscription(attrs \\ %{}) do
    %Subscription{}
    |> Subscription.changeset(attrs)
    |> Repo.insert()
  end

  # ...

  def create_invoice(attrs \\ %{}) do
    %Invoice{}
    |> Invoice.changeset(attrs)
    |> Repo.insert()
  end
end
