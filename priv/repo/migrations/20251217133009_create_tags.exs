defmodule AfyaFit.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      # nullable for global
      add :organization_id, references(:organizations, on_delete: :delete_all, type: :binary_id)
      add :name, :string, null: false
      add :color, :string

      timestamps()
    end

    create unique_index(:tags, [:organization_id, :name])
    create index(:tags, [:organization_id])

    # Workout Plan Tags
    create table(:workout_plan_tags, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workout_plan_id, references(:workout_plans, on_delete: :delete_all, type: :binary_id),
        null: false

      add :tag_id, references(:tags, on_delete: :delete_all, type: :binary_id), null: false

      timestamps()
    end

    create unique_index(:workout_plan_tags, [:workout_plan_id, :tag_id])

    # Nutrition Plan Tags
    create table(:nutrition_plan_tags, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :nutrition_plan_id,
          references(:nutrition_plans, on_delete: :delete_all, type: :binary_id),
          null: false

      add :tag_id, references(:tags, on_delete: :delete_all, type: :binary_id), null: false

      timestamps()
    end

    create unique_index(:nutrition_plan_tags, [:nutrition_plan_id, :tag_id])
  end
end
