defmodule AfyaFit.Repo.Migrations.CreateWorkoutPlans do
  use Ecto.Migration

  def change do
    create table(:workout_plans, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, on_delete: :delete_all, type: :binary_id),
        null: false

      add :trainer_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :name, :string, null: false
      add :description, :text
      add :duration_weeks, :integer
      add :difficulty, :string
      add :is_template, :boolean, default: false
      add :is_public, :boolean, default: false
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create index(:workout_plans, [:organization_id])
    create index(:workout_plans, [:trainer_id])
    create index(:workout_plans, [:is_template])
    create index(:workout_plans, [:inserted_at])
  end
end
