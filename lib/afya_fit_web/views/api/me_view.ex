defmodule AfyaFitWeb.API.MeView do
  @moduledoc false
  alias AfyaFitWeb.API.JSON.{NutritionPlanJSON, ProgressEntryJSON, TaskJSON}

  def render("index.json", %{nutrition_plans: nutrition_plans}) do
    NutritionPlanJSON.index(%{nutrition_plans: nutrition_plans})
  end

  def render("index.json", %{progress_entries: progress_entries}) do
    ProgressEntryJSON.index(%{progress_entries: progress_entries})
  end

  def render("index.json", %{tasks: tasks}) do
    TaskJSON.index(%{tasks: tasks})
  end

  def render("show.json", %{progress_entry: progress_entry}) do
    ProgressEntryJSON.show(%{progress_entry: progress_entry})
  end
end
