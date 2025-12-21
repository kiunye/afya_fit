defmodule AfyaFitWeb.API.WorkoutPlanView do
  @moduledoc false
  alias AfyaFitWeb.API.JSON.WorkoutPlanJSON

  def render("index.json", assigns) do
    WorkoutPlanJSON.index(assigns)
  end

  def render("show.json", assigns) do
    WorkoutPlanJSON.show(assigns)
  end
end
