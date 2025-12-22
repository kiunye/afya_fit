defmodule AfyaFitWeb.API.AuthView do
  @moduledoc false
  alias AfyaFitWeb.API.JSON.UserJSON

  def render("show.json", assigns) do
    UserJSON.show(assigns)
  end
end
