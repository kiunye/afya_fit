defmodule AfyaFitWeb.API.JSON.ClientJSON do
  @moduledoc """
  JSON serialization for Client resources.
  """

  def index(%{clients: clients}) do
    %{data: for(client <- clients, do: data(client))}
  end

  def show(%{client: client}) do
    %{data: data(client)}
  end

  defp data(%{id: id} = client) do
    %{
      id: id,
      email: client.email,
      first_name: client.first_name,
      last_name: client.last_name,
      phone: client.phone,
      avatar_url: client.avatar_url,
      timezone: client.timezone,
      email_verified: client.email_verified,
      organization_id: client.organization_id,
      inserted_at: client.inserted_at,
      updated_at: client.updated_at
    }
  end
end
