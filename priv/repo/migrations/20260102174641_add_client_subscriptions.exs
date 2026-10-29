defmodule AfyaFit.Repo.Migrations.AddClientSubscriptions do
  use Ecto.Migration

  def change do
    # Client subscriptions table (membership subscriptions for individual clients)
    create table(:client_subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :client_id, references(:users, on_delete: :delete_all, type: :binary_id),
        null: false

      add :organization_id, references(:organizations, on_delete: :delete_all, type: :binary_id),
        null: false

      add :plan_type, :string, null: false
      add :status, :string, null: false, default: "active"
      add :paystack_customer_code, :string
      add :paystack_subscription_code, :string
      add :current_period_start, :utc_datetime, null: false
      add :current_period_end, :utc_datetime, null: false
      add :cancel_at_period_end, :boolean, default: false
      add :cancelled_at, :utc_datetime
      add :reminder_preferences, :jsonb, default: fragment("'{}'::jsonb")

      timestamps()
    end

    create unique_index(:client_subscriptions, [:client_id])
    create index(:client_subscriptions, [:organization_id])
    create index(:client_subscriptions, [:status])
    create index(:client_subscriptions, [:current_period_end])
  end
end
