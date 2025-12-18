defmodule AfyaFit.Repo.Migrations.CreateNutritionPlans do
  use Ecto.Migration

  def change do
    create table(:nutrition_plans, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, on_delete: :delete_all, type: :binary_id),
        null: false

      add :trainer_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :client_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :name, :string, null: false
      add :description, :text
      add :daily_calories, :integer
      add :macros, :map
      add :start_date, :date, null: false
      add :end_date, :date
      add :is_template, :boolean, default: false
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create index(:nutrition_plans, [:organization_id])
    create index(:nutrition_plans, [:trainer_id])
    create index(:nutrition_plans, [:client_id])
    create index(:nutrition_plans, [:client_id, :start_date, :end_date])
  end
end
