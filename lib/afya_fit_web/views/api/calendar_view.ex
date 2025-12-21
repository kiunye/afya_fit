defmodule AfyaFitWeb.API.CalendarView do
  @moduledoc false
  alias AfyaFitWeb.API.JSON.CalendarEventJSON

  def render("index.json", assigns) do
    CalendarEventJSON.index(assigns)
  end

  def render("show.json", assigns) do
    CalendarEventJSON.show(assigns)
  end
end
