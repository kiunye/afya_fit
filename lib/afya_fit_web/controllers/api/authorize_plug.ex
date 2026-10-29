defmodule AfyaFitWeb.API.AuthorizePlug do
  @moduledoc """
  Authorizes every action of a controller that acts on a single resource type
  rather than on a loaded record.

      plug AfyaFitWeb.API.AuthorizePlug,
        resource: :subscription,
        actions: %{show: :read, invoices: :read},
        default: :manage

  Controller actions are mapped to policy actions with `:actions`; any action
  not listed uses `:default`. A denial is rendered by the fallback controller.
  """
  import Plug.Conn

  alias AfyaFit.Authorization
  alias AfyaFitWeb.API.FallbackController

  def init(opts) do
    %{
      resource: Keyword.fetch!(opts, :resource),
      actions: Keyword.get(opts, :actions, %{}),
      default: Keyword.fetch!(opts, :default)
    }
  end

  def call(conn, %{resource: resource, actions: actions, default: default}) do
    action = Map.get(actions, Phoenix.Controller.action_name(conn), default)

    case Authorization.authorize(conn.assigns.current_scope, action, resource) do
      :ok -> conn
      {:error, _reason} = error -> conn |> FallbackController.call(error) |> halt()
    end
  end
end
