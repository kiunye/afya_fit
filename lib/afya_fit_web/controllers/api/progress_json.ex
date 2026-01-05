defmodule AfyaFitWeb.API.ProgressJSON do
  @moduledoc """
  JSON serialization for Progress resources.
  This module delegates to AfyaFitWeb.API.JSON.ProgressEntryJSON.
  """
  alias AfyaFitWeb.API.JSON.ProgressEntryJSON, as: JSON

  defdelegate index(assigns), to: JSON
  defdelegate show(assigns), to: JSON
end
