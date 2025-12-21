defmodule AfyaFitWeb.API.ProgressView do
  @moduledoc false
  alias AfyaFitWeb.API.JSON.ProgressEntryJSON

  def render("index.json", assigns) do
    ProgressEntryJSON.index(assigns)
  end

  def render("show.json", assigns) do
    ProgressEntryJSON.show(assigns)
  end
end
