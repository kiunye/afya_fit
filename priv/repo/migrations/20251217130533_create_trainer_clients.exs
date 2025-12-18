defmodule AfyaFit.Repo.Migrations.CreateTrainerClients do
  use Ecto.Migration

  def change do
    create table(:trainer_clients, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :trainer_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :client_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :status, :string, null: false, default: "active"
      add :started_at, :utc_datetime, null: false, default: fragment("NOW()")
      add :ended_at, :utc_datetime
      add :notes, :text

      timestamps()
    end

    create index(:trainer_clients, [:trainer_id])
    create index(:trainer_clients, [:client_id])
    create index(:trainer_clients, [:status])
    create unique_index(:trainer_clients, [:trainer_id, :client_id])

    create constraint(:trainer_clients, :trainer_cannot_be_client,
             check: "trainer_id != client_id"
           )
  end
end
