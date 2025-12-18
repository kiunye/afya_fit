defmodule AfyaFit.Repo.Migrations.CreateClientWorkouts do
  use Ecto.Migration

  def change do
    create table(:client_workouts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :client_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      add :workout_plan_id, references(:workout_plans, on_delete: :delete_all, type: :binary_id),
        null: false

      add :assigned_by, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :assigned_date, :date, null: false
      add :start_date, :date, null: false
      add :end_date, :date
      add :status, :string, null: false, default: "assigned"
      add :completed_at, :utc_datetime
      add :notes, :text

      timestamps()
    end

    create index(:client_workouts, [:client_id])
    create index(:client_workouts, [:workout_plan_id])
    create index(:client_workouts, [:status])
    create index(:client_workouts, [:client_id, :start_date, :end_date])

    # Workout Completions
    create table(:workout_completions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :client_workout_id,
          references(:client_workouts, on_delete: :delete_all, type: :binary_id),
          null: false

      add :completed_date, :date, null: false
      add :duration_minutes, :integer
      add :notes, :text
      add :rating, :integer

      timestamps(updated_at: false)
    end

    create index(:workout_completions, [:client_workout_id])
    create index(:workout_completions, [:completed_date])
  end
end
