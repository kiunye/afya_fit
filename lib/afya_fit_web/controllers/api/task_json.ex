defmodule AfyaFitWeb.API.TaskJSON do
  @moduledoc """
  JSON serialization for Task resources.
  This module delegates to AfyaFitWeb.API.JSON.TaskJSON.
  """
  alias AfyaFitWeb.API.JSON.TaskJSON, as: JSON

  defdelegate index(assigns), to: JSON
  defdelegate show(assigns), to: JSON
end
