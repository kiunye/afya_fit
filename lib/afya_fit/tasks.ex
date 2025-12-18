defmodule AfyaFit.Tasks do
  @moduledoc """
  The Tasks context.
  """
  import Ecto.Query, warn: false
  alias AfyaFit.Repo
  alias AfyaFit.Tasks.{Task, TaskCompletion, TaskRecurrence}

  def list_tasks(client_id) do
    Task
    |> where([t], t.client_id == ^client_id)
    |> Repo.all()
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
