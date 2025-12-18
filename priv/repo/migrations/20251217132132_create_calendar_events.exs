defmodule AfyaFit.Repo.Migrations.CreateCalendarEvents do
  use Ecto.Migration

  def change do
    create table(:calendar_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, on_delete: :delete_all, type: :binary_id),
        null: false

      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :title, :string, null: false
      add :description, :text
      add :event_type, :string, null: false
      add :start_time, :utc_datetime, null: false
      add :end_time, :utc_datetime
      add :is_all_day, :boolean, default: false
      add :timezone, :string
      add :location, :string
      add :related_id, :binary_id
      add :related_type, :string

      timestamps()
    end

    create index(:calendar_events, [:organization_id])
    create index(:calendar_events, [:user_id])
    create index(:calendar_events, [:user_id, :start_time, :end_time])
    create index(:calendar_events, [:event_type])
    create index(:calendar_events, [:related_type, :related_id])

    create table(:calendar_event_attendees, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :event_id, references(:calendar_events, on_delete: :delete_all, type: :binary_id),
        null: false

      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :status, :string, default: "accepted"

      timestamps(updated_at: false)
    end

    create unique_index(:calendar_event_attendees, [:event_id, :user_id])
    create index(:calendar_event_attendees, [:user_id])
  end
end
