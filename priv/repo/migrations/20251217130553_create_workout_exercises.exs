defmodule AfyaFit.Repo.Migrations.CreateWorkoutExercises do
  use Ecto.Migration

  def change do
    create table(:workout_exercises, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workout_plan_id, references(:workout_plans, on_delete: :delete_all, type: :binary_id),
        null: false

      add :exercise_id, references(:exercises, on_delete: :nilify_all, type: :binary_id)
      add :exercise_name, :string, null: false
      add :sets, :integer
      add :reps, :string
      add :weight, :string
      add :rest_seconds, :integer
      add :video_url, :string
      add :instructions, :text
      add :order_index, :integer, null: false
      add :day_number, :integer

      timestamps(updated_at: false)
    end

    create index(:workout_exercises, [:workout_plan_id])
    create index(:workout_exercises, [:exercise_id])
    create index(:workout_exercises, [:workout_plan_id, :day_number, :order_index])
  end
end
