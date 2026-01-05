defmodule AfyaFit.Billing.ClientSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "client_subscriptions" do
    belongs_to :client, AfyaFit.Accounts.User
    belongs_to :organization, AfyaFit.Organizations.Organization

    field :plan_type, :string
    field :status, :string, default: "active"
    field :paystack_customer_code, :string
    field :paystack_subscription_code, :string
    field :current_period_start, :utc_datetime
    field :current_period_end, :utc_datetime
    field :cancel_at_period_end, :boolean, default: false
    field :cancelled_at, :utc_datetime
    field :reminder_preferences, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def changeset(client_subscription, attrs) do
    client_subscription
    |> cast(attrs, [
      :client_id,
      :organization_id,
      :plan_type,
      :status,
      :paystack_customer_code,
      :paystack_subscription_code,
      :current_period_start,
      :current_period_end,
      :cancel_at_period_end,
      :cancelled_at,
      :reminder_preferences
    ])
    |> validate_required([
      :client_id,
      :organization_id,
      :plan_type,
      :status,
      :current_period_start,
      :current_period_end
    ])
    |> validate_inclusion(:plan_type, ["monthly", "quarterly", "yearly"])
    |> validate_inclusion(:status, ["active", "cancelled", "expired", "past_due"])
    |> unique_constraint(:client_id)
  end
end
