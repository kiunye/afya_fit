defmodule AfyaFitWeb.API.JSON.UserJSON do
  @moduledoc """
  JSON serialization for User resources.
  """

  def index(%{users: users}) do
    %{data: for(user <- users, do: data(user))}
  end

  def show(%{user: user}) do
    %{data: data(user)}
  end

  defp data(%{id: id} = user) do
    %{
      id: id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      phone: user.phone,
      avatar_url: user.avatar_url,
      role: user.role,
      timezone: user.timezone,
      email_verified: user.email_verified,
      organization_id: user.organization_id,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end
end
