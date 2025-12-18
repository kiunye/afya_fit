defmodule AfyaFit.Repo.Migrations.CreateUserPreferences do
  use Ecto.Migration

  def change do
    create table(:user_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :notification_preferences, :map
      add :dashboard_preferences, :map
      add :language, :string, default: "en"
      add :theme, :string, default: "light"

      timestamps()
    end

    create unique_index(:user_preferences, [:user_id])

    create table(:device_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :token, :string, null: false
      add :platform, :string, null: false
      add :device_id, :string
      add :is_active, :boolean, default: true
      add :last_used_at, :utc_datetime

      timestamps()
    end

    create unique_index(:device_tokens, [:token])
    create index(:device_tokens, [:user_id])
  end
end
