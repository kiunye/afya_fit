defmodule AfyaFitWeb.API.NutritionPlanJSON do
  @moduledoc """
  JSON serialization for NutritionPlan resources.
  This module delegates to AfyaFitWeb.API.JSON.NutritionPlanJSON.
  """
  alias AfyaFitWeb.API.JSON.NutritionPlanJSON, as: JSON

  defdelegate index(assigns), to: JSON
  defdelegate show(assigns), to: JSON
end
