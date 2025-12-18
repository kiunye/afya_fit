defmodule AfyaFit.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, on_delete: :delete_all, type: :binary_id),
        null: false

      add :trainer_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :client_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :title, :string, null: false
      add :description, :text
      add :task_type, :string, null: false
      add :priority, :string, default: "medium"
      add :due_date, :utc_datetime
      add :is_recurring, :boolean, default: false
      add :status, :string, null: false, default: "pending"
      add :completed_at, :utc_datetime

      timestamps()
    end

    create index(:tasks, [:organization_id])
    create index(:tasks, [:trainer_id])
    create index(:tasks, [:client_id])
    create index(:tasks, [:status])
    create index(:tasks, [:client_id, :due_date])
    create index(:tasks, [:task_type])

    # Task Recurrence
    create table(:task_recurrence, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :task_id, references(:tasks, on_delete: :delete_all, type: :binary_id), null: false
      add :frequency, :string, null: false
      add :interval, :integer, default: 1
      add :days_of_week, {:array, :integer}
      add :day_of_month, :integer
      add :end_date, :date
      add :max_occurrences, :integer

      timestamps(updated_at: false)
    end

    create unique_index(:task_recurrence, [:task_id])

    # Task Completions
    create table(:task_completions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :task_id, references(:tasks, on_delete: :delete_all, type: :binary_id), null: false
      add :completed_date, :date, null: false
      add :notes, :text

      timestamps(updated_at: false)
    end

    create unique_index(:task_completions, [:task_id, :completed_date])
    create index(:task_completions, [:completed_date])
  end
end
