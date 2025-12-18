defmodule AfyaFit.Nutrition do
  @moduledoc """
  The Nutrition context.
  """
  import Ecto.Query, warn: false
  alias AfyaFit.Nutrition.{NutritionMeal, NutritionPlan}
  alias AfyaFit.Repo

  def list_nutrition_plans do
    Repo.all(NutritionPlan)
  end

  def get_nutrition_plan!(id), do: Repo.get!(NutritionPlan, id)

  def create_nutrition_plan(attrs \\ %{}) do
    %NutritionPlan{}
    |> NutritionPlan.changeset(attrs)
    |> Repo.insert()
  end

  def update_nutrition_plan(%NutritionPlan{} = nutrition_plan, attrs) do
    nutrition_plan
    |> NutritionPlan.changeset(attrs)
    |> Repo.update()
  end

  def delete_nutrition_plan(%NutritionPlan{} = nutrition_plan) do
    Repo.delete(nutrition_plan)
  end

  def change_nutrition_plan(%NutritionPlan{} = nutrition_plan, attrs \\ %{}) do
    NutritionPlan.changeset(nutrition_plan, attrs)
  end

  def create_nutrition_meal(attrs \\ %{}) do
    %NutritionMeal{}
    |> NutritionMeal.changeset(attrs)
    |> Repo.insert()
  end
end
