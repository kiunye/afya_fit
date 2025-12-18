defmodule AfyaFit.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, on_delete: :delete_all, type: :binary_id),
        null: false

      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :role, :string, null: false
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :phone, :string
      add :avatar_url, :string
      add :timezone, :string, default: "UTC"
      add :email_verified, :boolean, default: false
      add :email_verified_at, :utc_datetime
      add :last_login_at, :utc_datetime
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create unique_index(:users, [:email])
    create index(:users, [:organization_id])
    create index(:users, [:role])
    create index(:users, [:organization_id, :role])
  end
end
