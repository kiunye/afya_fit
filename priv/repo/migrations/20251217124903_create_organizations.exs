defmodule AfyaFit.Repo.Migrations.CreateOrganizations do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", ""
    execute "CREATE EXTENSION IF NOT EXISTS \"pg_trgm\"", ""

    create table(:organizations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :subdomain, :string, null: false
      add :plan_type, :string, null: false, default: "free"
      add :status, :string, null: false, default: "active"
      add :branding_config, :map
      add :settings, :map
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create unique_index(:organizations, [:subdomain])
    create index(:organizations, [:status])
  end
end
