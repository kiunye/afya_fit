defmodule AfyaFitWeb.API.ClientJSON do
  @moduledoc """
  JSON serialization for Client resources.
  This module delegates to AfyaFitWeb.API.JSON.ClientJSON.
  """
  alias AfyaFitWeb.API.JSON.ClientJSON, as: JSON

  defdelegate index(assigns), to: JSON
  defdelegate show(assigns), to: JSON
end
