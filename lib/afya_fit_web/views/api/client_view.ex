defmodule AfyaFitWeb.API.ClientView do
  @moduledoc false
  alias AfyaFitWeb.API.JSON.ClientJSON

  def render("index.json", assigns) do
    ClientJSON.index(assigns)
  end

  def render("show.json", assigns) do
    ClientJSON.show(assigns)
  end
end
