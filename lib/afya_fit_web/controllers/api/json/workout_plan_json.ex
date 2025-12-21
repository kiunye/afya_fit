defmodule AfyaFitWeb.API.JSON.WorkoutPlanJSON do
  @moduledoc """
  JSON serialization for WorkoutPlan resources.
  """

  def index(%{workout_plans: workout_plans}) do
    %{data: for(plan <- workout_plans, do: data(plan))}
  end

  def show(%{workout_plan: workout_plan}) do
    %{data: data(workout_plan)}
  end

  defp data(%{id: id} = plan) do
    %{
      id: id,
      name: plan.name,
      description: plan.description,
      duration_weeks: plan.duration_weeks,
      difficulty: plan.difficulty,
      is_template: plan.is_template,
      is_public: plan.is_public,
      organization_id: plan.organization_id,
      trainer_id: plan.trainer_id,
      inserted_at: plan.inserted_at,
      updated_at: plan.updated_at
    }
  end
end
