defmodule AfyaFit.Billing.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "subscriptions" do
    belongs_to :organization, AfyaFit.Organizations.Organization

    field :plan_type, :string
    field :status, :string, default: "active"
    field :paystack_customer_code, :string
    field :paystack_subscription_code, :string
    field :current_period_start, :utc_datetime
    field :current_period_end, :utc_datetime
    field :cancel_at_period_end, :boolean, default: false
    field :cancelled_at, :utc_datetime

    has_many :invoices, AfyaFit.Billing.Invoice

    timestamps(type: :utc_datetime)
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :organization_id,
      :plan_type,
      :status,
      :paystack_customer_code,
      :paystack_subscription_code,
      :current_period_start,
      :current_period_end,
      :cancel_at_period_end,
      :cancelled_at
    ])
    |> validate_required([
      :organization_id,
      :plan_type,
      :status,
      :current_period_start,
      :current_period_end
    ])
    |> validate_inclusion(:plan_type, ["free", "pro", "enterprise"])
    |> validate_inclusion(:status, ["active", "cancelled", "expired", "past_due"])
    |> unique_constraint(:organization_id)
  end
end
