defmodule AfyaFit.Authorization.Policy.Task do
  @moduledoc false
  @behaviour AfyaFit.Authorization.Policy

  import Ecto.Query

  alias AfyaFit.Authorization.Policy
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Tasks.Task

  @impl true
  def check(scope, _action, task) do
    Policy.allow?(
      Scope.self?(scope, task.trainer_id) or
        Scope.manages_client?(scope, task.client_id) or
        Scope.self?(scope, task.client_id)
    )
  end

  @impl true
  def visible(scope) do
    tasks = Policy.tenant(Task, scope)

    case Scope.role(scope) do
      role when role in [:admin, :org_admin] ->
        tasks

      :trainer ->
        client_ids = Policy.linked_client_ids(scope)
        where(tasks, [t], t.trainer_id == ^scope.user.id or t.client_id in ^client_ids)

      :client ->
        where(tasks, [t], t.client_id == ^scope.user.id)

      _ ->
        Policy.none(tasks)
    end
  end
end
