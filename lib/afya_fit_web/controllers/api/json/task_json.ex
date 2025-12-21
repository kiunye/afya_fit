defmodule AfyaFitWeb.API.JSON.TaskJSON do
  @moduledoc """
  JSON serialization for Task resources.
  """

  def index(%{tasks: tasks}) do
    %{data: for(task <- tasks, do: data(task))}
  end

  def show(%{task: task}) do
    %{data: data(task)}
  end

  defp data(%{id: id} = task) do
    %{
      id: id,
      title: task.title,
      description: task.description,
      task_type: task.task_type,
      priority: task.priority,
      due_date: task.due_date,
      is_recurring: task.is_recurring,
      status: task.status,
      completed_at: task.completed_at,
      organization_id: task.organization_id,
      trainer_id: task.trainer_id,
      client_id: task.client_id,
      inserted_at: task.inserted_at,
      updated_at: task.updated_at
    }
  end
end
