defmodule AfyaFit.Tasks do
  @moduledoc """
  The Tasks context.
  """
  import Ecto.Query, warn: false
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Repo
  alias AfyaFit.Tasks.{Task, TaskCompletion, TaskRecurrence}

  def list_tasks(client_id \\ nil) do
    query = Task

    query =
      if client_id do
        where(query, [t], t.client_id == ^client_id)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Lists the tasks the scope's user may see: every task for platform admins, the
  organization's tasks for organization admins, a trainer's own and linked
  clients' tasks, and a client's own tasks.
  """
  def list_tasks_for(%Scope{user: user} = scope) do
    in_org = from t in Task, where: t.organization_id == ^user.organization_id

    case Scope.role(scope) do
      :admin ->
        Repo.all(Task)

      :org_admin ->
        Repo.all(in_org)

      :trainer ->
        client_ids = MapSet.to_list(scope.client_ids)
        Repo.all(from t in in_org, where: t.trainer_id == ^user.id or t.client_id in ^client_ids)

      :client ->
        Repo.all(from t in in_org, where: t.client_id == ^user.id)

      _ ->
        []
    end
  end

  @doc "Lists the tasks assigned to `client`."
  def list_client_tasks(%{id: client_id, organization_id: organization_id}) do
    Repo.all(
      from t in Task, where: t.organization_id == ^organization_id and t.client_id == ^client_id
    )
  end

  def get_task!(id), do: Repo.get!(Task, id)

  def create_task(attrs \\ %{}) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  def update_task(%Task{} = task, attrs) do
    task
    |> Task.changeset(attrs)
    |> Repo.update()
  end

  def delete_task(%Task{} = task) do
    Repo.delete(task)
  end

  def change_task(%Task{} = task, attrs \\ %{}) do
    Task.changeset(task, attrs)
  end

  # Recurrence
  def create_task_recurrence(attrs \\ %{}) do
    %TaskRecurrence{}
    |> TaskRecurrence.changeset(attrs)
    |> Repo.insert()
  end

  # Completions
  def create_task_completion(attrs \\ %{}) do
    %TaskCompletion{}
    |> TaskCompletion.changeset(attrs)
    |> Repo.insert()
  end
end
