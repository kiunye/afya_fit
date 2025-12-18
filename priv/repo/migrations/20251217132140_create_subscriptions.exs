defmodule AfyaFit.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true

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

      timestamps()
    end

    create unique_index(:subscriptions, [:organization_id])
    create index(:subscriptions, [:status])

    create table(:invoices, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :subscription_id, references(:subscriptions, on_delete: :delete_all, type: :binary_id),
        null: false

      add :invoice_number, :string, null: false
      add :amount, :decimal, precision: 10, scale: 2, null: false
      add :currency, :string, default: "NGN"
      add :status, :string, null: false, default: "pending"
      add :paystack_invoice_code, :string
      add :due_date, :date, null: false
      add :paid_at, :utc_datetime

      timestamps()
    end

    create unique_index(:invoices, [:invoice_number])
    create index(:invoices, [:subscription_id])
  end
end
