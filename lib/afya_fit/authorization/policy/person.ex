defmodule AfyaFit.Authorization.Policy.Person do
  @moduledoc """
  People: clients (and, for `check/3`, trainers). `visible/1` lists clients.
  """
  @behaviour AfyaFit.Authorization.Policy

  import Ecto.Query

  alias AfyaFit.Accounts.User
  alias AfyaFit.Authorization.Policy
  alias AfyaFit.Authorization.Scope

  @impl true
  def check(scope, _action, record) do
    Policy.allow?(
      case Scope.role(scope) do
        :trainer -> Scope.manages_client?(scope, record.id)
        :client -> Scope.self?(scope, record.id)
        _ -> false
      end
    )
  end

  @impl true
  def visible(scope) do
    clients = from u in User, where: u.role == "client" and is_nil(u.deleted_at)

    case Scope.role(scope) do
      :admin ->
        clients

      :org_admin ->
        where(clients, [u], u.organization_id == ^scope.user.organization_id)

      :trainer ->
        ids = Policy.linked_client_ids(scope)
        where(clients, [u], u.id in ^ids)

      :client ->
        where(clients, [u], u.id == ^scope.user.id)

      _ ->
        Policy.none(clients)
    end
  end
end
