defmodule AfyaFitWeb.API.CalendarJSON do
  @moduledoc """
  JSON serialization for Calendar resources.
  This module delegates to AfyaFitWeb.API.JSON.CalendarEventJSON.
  """
  alias AfyaFitWeb.API.JSON.CalendarEventJSON, as: JSON

  defdelegate index(assigns), to: JSON
  defdelegate show(assigns), to: JSON
end
