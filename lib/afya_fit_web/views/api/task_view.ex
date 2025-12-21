defmodule AfyaFitWeb.API.TaskView do
  @moduledoc false
  alias AfyaFitWeb.API.JSON.TaskJSON

  def render("index.json", assigns) do
    TaskJSON.index(assigns)
  end

  def render("show.json", assigns) do
    TaskJSON.show(assigns)
  end
end
