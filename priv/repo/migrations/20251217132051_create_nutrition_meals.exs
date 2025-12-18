defmodule AfyaFit.Repo.Migrations.CreateNutritionMeals do
  use Ecto.Migration

  def change do
    create table(:nutrition_meals, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :nutrition_plan_id,
          references(:nutrition_plans, on_delete: :delete_all, type: :binary_id),
          null: false

      add :meal_type, :string, null: false
      add :name, :string, null: false
      add :calories, :integer
      add :macros, :map
      add :ingredients, :text
      add :instructions, :text
      add :image_url, :string
      add :order_index, :integer, null: false
      add :day_number, :integer

      timestamps(updated_at: false)
    end

    create index(:nutrition_meals, [:nutrition_plan_id])
    create index(:nutrition_meals, [:meal_type])
    create index(:nutrition_meals, [:nutrition_plan_id, :day_number, :meal_type, :order_index])
  end
end
