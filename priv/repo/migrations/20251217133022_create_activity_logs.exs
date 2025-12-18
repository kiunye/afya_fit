defmodule AfyaFit.Repo.Migrations.CreateActivityLogs do
  use Ecto.Migration

  def change do
    create table(:activity_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, on_delete: :delete_all, type: :binary_id),
        null: false

      add :user_id, references(:users, on_delete: :nilify_all, type: :binary_id)
      add :action, :string, null: false
      add :resource_type, :string
      add :resource_id, :binary_id
      add :metadata, :map
      add :ip_address, :inet
      add :user_agent, :text

      timestamps()
    end

    create index(:activity_logs, [:organization_id])
    create index(:activity_logs, [:user_id])
    create index(:activity_logs, [:inserted_at])
  end
end
