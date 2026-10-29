defmodule AfyaFit.Repo do
  use Ecto.Repo,
    otp_app: :afya_fit,
    adapter: Ecto.Adapters.Postgres

  @moduledoc """
  The repo, plus the tenant context Postgres row-level security reads.

  RLS is the second wall behind `AfyaFit.Authorization`: if a query forgets its
  organization filter, Postgres returns nothing instead of another tenant's
  rows. It is off unless `config :afya_fit, AfyaFit.RLS, enforce: true` (or
  `RLS_ENFORCE=true` at runtime). When it is on:

    * connections run as the non-owner role in `:app_role`, because owners
      bypass RLS;
    * `with_scope/2` and `unscoped/1` pin a connection and set
      `app.current_organization_id` and `app.current_user_role` on it, which
      the policies read, then reset them. Code outside both sees no rows.

  When it is off, both functions only call the function they are given.
  """

  alias AfyaFit.Authorization.Scope

  @context_key :afya_rls_context

  @impl true
  def init(_type, config) do
    if enforce?() and role_on_connect?() do
      {:ok, Keyword.put(config, :after_connect, {__MODULE__, :set_role, [app_role()]})}
    else
      {:ok, config}
    end
  end

  @doc false
  def set_role(conn, role) do
    if role =~ ~r/\A[a-z_][a-z0-9_]*\z/ do
      Postgrex.query!(conn, "SET ROLE #{role}", [])
    else
      raise ArgumentError, "invalid RLS role name: #{inspect(role)}"
    end
  end

  @doc "Whether row-level security is being enforced for this node."
  def enforce?, do: config(:enforce, false)

  @doc "The database role the app runs as when RLS is enforced."
  def app_role, do: config(:app_role, "afya_fit_app")

  defp role_on_connect?, do: config(:role_on_connect, true)

  defp config(key, default) do
    :afya_fit |> Application.get_env(AfyaFit.RLS, []) |> Keyword.get(key, default)
  end

  @doc """
  Runs `fun` with the requester's organization and role visible to RLS, on one connection.

  Accepts a loaded `Scope`. Anything else (signed-out visitors, jobs) runs
  `unscoped/1`, because it has no organization to be limited to.
  """
  def with_scope(%Scope{user: %{organization_id: org, role: role}}, fun)
      when is_function(fun, 0),
      do: run_in_context({org, role}, fun)

  def with_scope(_scope, fun) when is_function(fun, 0), do: unscoped(fun)

  @doc """
  Runs `fun` as the system: for sign-in, registration, webhooks and jobs that
  work across organizations, before any organization is known.
  """
  def unscoped(fun) when is_function(fun, 0), do: run_in_context({nil, "system"}, fun)

  @doc false
  # Test helper: makes `{nil, "system"}` the ambient context of the current
  # sandbox transaction, so fixtures can insert before a request scopes itself.
  def put_ambient_context(context) do
    set_context(context)
    Process.put(@context_key, context)
    :ok
  end

  defp run_in_context(context, fun) do
    previous = Process.get(@context_key)

    cond do
      not enforce?() ->
        fun.()

      previous == context ->
        fun.()

      true ->
        # A pinned connection rather than a transaction: a failed transaction
        # inside `fun` (a Multi with a bad changeset) must not poison the rest
        # of the request. The setting is session-level and always reset; if the
        # process is killed instead, DBConnection drops the connection.
        checkout(fn ->
          restore = if config(:restore_context, false), do: read_context(), else: {nil, nil}
          set_context(context)
          Process.put(@context_key, context)

          try do
            fun.()
          after
            Process.put(@context_key, previous)
            set_context(restore)
          end
        end)
    end
  end

  # What the connection currently has, so a transaction that shares it with
  # other processes (the test sandbox) can put it back.
  defp read_context do
    %{rows: [[org, role]]} =
      Ecto.Adapters.SQL.query!(
        __MODULE__,
        "SELECT current_setting('app.current_organization_id', true), " <>
          "current_setting('app.current_user_role', true)",
        []
      )

    {org, role}
  end

  defp set_context({org, role}) do
    Ecto.Adapters.SQL.query!(
      __MODULE__,
      "SELECT set_config('app.current_organization_id', $1, false), " <>
        "set_config('app.current_user_role', $2, false)",
      [org || "", role || ""]
    )

    :ok
  end
end
