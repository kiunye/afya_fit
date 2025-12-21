defmodule AfyaFitWeb.API.JSON.NutritionPlanJSON do
  @moduledoc """
  JSON serialization for NutritionPlan resources.
  """

  def index(%{nutrition_plans: nutrition_plans}) do
    %{data: for(plan <- nutrition_plans, do: data(plan))}
  end

  def show(%{nutrition_plan: nutrition_plan}) do
    %{data: data(nutrition_plan)}
  end

  defp data(%{id: id} = plan) do
    %{
      id: id,
      name: plan.name,
      description: plan.description,
      daily_calories: plan.daily_calories,
      macros: plan.macros || %{},
      start_date: plan.start_date,
      end_date: plan.end_date,
      is_template: plan.is_template,
      organization_id: plan.organization_id,
      trainer_id: plan.trainer_id,
      client_id: plan.client_id,
      inserted_at: plan.inserted_at,
      updated_at: plan.updated_at
    }
  end
end
