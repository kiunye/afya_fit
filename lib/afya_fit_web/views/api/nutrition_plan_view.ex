defmodule AfyaFitWeb.API.NutritionPlanView do
  @moduledoc false
  alias AfyaFitWeb.API.JSON.NutritionPlanJSON

  def render("index.json", assigns) do
    NutritionPlanJSON.index(assigns)
  end

  def render("show.json", assigns) do
    NutritionPlanJSON.show(assigns)
  end
end
