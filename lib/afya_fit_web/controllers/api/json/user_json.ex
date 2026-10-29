defmodule AfyaFitWeb.API.JSON.UserJSON do
  @moduledoc """
  JSON serialization for User resources.
  """

  def index(%{users: users}) do
    %{data: for(user <- users, do: data(user))}
  end

  def show(assigns) do
    %{data: data(assigns.user)}
    |> put_if(:token, Map.get(assigns, :token))
    |> put_if(:access, assigns |> Map.get(:scope) |> access())
  end

  defp data(%{id: id} = user) do
    %{
      id: id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      phone: user.phone,
      avatar_url: user.avatar_url,
      role: AfyaFit.Accounts.User.legacy_role(user),
      account_role: user.role,
      timezone: user.timezone,
      email_verified: user.email_verified,
      organization_id: user.organization_id,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)

  defp access(nil), do: nil
  defp access(scope), do: AfyaFitWeb.API.JSON.AccessJSON.build(scope)
end
