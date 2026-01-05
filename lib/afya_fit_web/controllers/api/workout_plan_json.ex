defmodule AfyaFitWeb.API.WorkoutPlanJSON do
  @moduledoc """
  JSON serialization for WorkoutPlan resources.
  This module delegates to AfyaFitWeb.API.JSON.WorkoutPlanJSON.
  """
  alias AfyaFitWeb.API.JSON.WorkoutPlanJSON, as: JSON

  defdelegate index(assigns), to: JSON
  defdelegate show(assigns), to: JSON
end
