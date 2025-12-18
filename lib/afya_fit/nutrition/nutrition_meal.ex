defmodule AfyaFit.Nutrition.NutritionMeal do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "nutrition_meals" do
    belongs_to :nutrition_plan, AfyaFit.Nutrition.NutritionPlan

    field :meal_type, :string
    field :name, :string
    field :calories, :integer
    field :macros, :map
    field :ingredients, :string
    field :instructions, :string
    field :image_url, :string
    field :order_index, :integer
    field :day_number, :integer

    timestamps(updated_at: false, type: :utc_datetime)
  end

  def changeset(nutrition_meal, attrs) do
    nutrition_meal
    |> cast(attrs, [
      :nutrition_plan_id,
      :meal_type,
      :name,
      :calories,
      :macros,
      :ingredients,
      :instructions,
      :image_url,
      :order_index,
      :day_number
    ])
    |> validate_required([:nutrition_plan_id, :meal_type, :name, :order_index])
    |> validate_inclusion(:meal_type, [
      "breakfast",
      "lunch",
      "dinner",
      "snack",
      "pre_workout",
      "post_workout"
    ])
  end
end
