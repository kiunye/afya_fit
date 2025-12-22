defmodule AfyaFit.Repo.RLSHelper do
  @moduledoc """
  Helper module for managing Row-Level Security (RLS) context in database queries.

  This module provides functions to set the RLS context (organization_id and user_role)
  that will be used by PostgreSQL RLS policies to filter data.

  ## Usage

      # Set RLS context for a user's organization
      AfyaFit.Repo.RLSHelper.set_organization_context(conn, user)

      # Or set it explicitly
      AfyaFit.Repo.RLSHelper.set_organization_id(repo, organization_id)
      AfyaFit.Repo.RLSHelper.set_user_role(repo, "trainer")

      # Use in a transaction
      AfyaFit.Repo.transaction(fn ->
        AfyaFit.Repo.RLSHelper.set_organization_id(AfyaFit.Repo, org_id)
        # Your queries here will be filtered by RLS
      end)
  """

  alias Ecto.Adapters.SQL

  @doc """
  Sets the organization context for RLS policies.

  This should be called before executing queries that need to be filtered by organization.
  """
  def set_organization_context(conn, user) when is_map(user) do
    set_organization_id(conn, user.organization_id)
    set_user_role(conn, user.role)
  end

  def set_organization_context(repo, organization_id, user_role) do
    set_organization_id(repo, organization_id)
    set_user_role(repo, user_role)
  end

  @doc """
  Sets the current organization ID for RLS policies.

  This sets the PostgreSQL session variable `app.current_organization_id` that is used
  by RLS policies to filter data by organization.
  """
  def set_organization_id(conn_or_repo, organization_id) when is_binary(organization_id) do
    repo = get_repo(conn_or_repo)

    SQL.query!(
      repo,
      "SET LOCAL app.current_organization_id = $1",
      [organization_id]
    )
  end

  def set_organization_id(_conn_or_repo, nil), do: :ok

  @doc """
  Sets the current user role for RLS policies.

  This sets the PostgreSQL session variable `app.current_user_role` that can be used
  by RLS policies for role-based access control.
  """
  def set_user_role(conn_or_repo, role) when is_binary(role) do
    repo = get_repo(conn_or_repo)

    SQL.query!(
      repo,
      "SET LOCAL app.current_user_role = $1",
      [role]
    )
  end

  def set_user_role(_conn_or_repo, nil), do: :ok

  @doc """
  Clears the RLS context.

  This clears both organization_id and user_role session variables.
  """
  def clear_context(conn_or_repo) do
    repo = get_repo(conn_or_repo)

    SQL.query!(repo, "RESET app.current_organization_id", [])
    SQL.query!(repo, "RESET app.current_user_role", [])
  end

  # Helper to extract repo from conn or use directly
  defp get_repo(%{private: %{phoenix_repo: repo}}), do: repo
  defp get_repo(repo) when is_atom(repo), do: repo
  defp get_repo(_), do: AfyaFit.Repo
end
