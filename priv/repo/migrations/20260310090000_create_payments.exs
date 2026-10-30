defmodule AfyaFit.Repo.Migrations.CreatePayments do
  use Ecto.Migration

  # One row per payment attempt, whatever the provider (Paystack or M-Pesa via
  # Daraja). It is the audit trail and the idempotency key: a webhook that
  # arrives twice settles the same row once.
  def up do
    create table(:payments, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :provider, :string, null: false
      add :plan_type, :string, null: false
      add :amount, :decimal, precision: 12, scale: 2, null: false
      add :currency, :string, null: false, default: "KES"
      add :status, :string, null: false, default: "pending"
      add :reference, :string, null: false
      add :provider_reference, :string
      add :phone, :string
      add :callback_token, :string
      add :receipt, :string
      add :failure_reason, :string
      add :provider_payload, :map, null: false, default: %{}
      add :paid_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:payments, [:reference])
    create unique_index(:payments, [:callback_token], where: "callback_token IS NOT NULL")
    create index(:payments, [:organization_id])
    create index(:payments, [:status, :inserted_at])
    create index(:payments, [:provider_reference])

    execute "ALTER TABLE payments ENABLE ROW LEVEL SECURITY"

    execute """
    CREATE POLICY tenant_isolation ON payments
    USING (app_privileged() OR organization_id = app_org_id())
    WITH CHECK (app_privileged() OR organization_id = app_org_id())
    """
  end

  def down do
    drop table(:payments)
  end
end
