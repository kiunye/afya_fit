defmodule AfyaFit.Workers.TaskAutomationWorker do
  @moduledoc """
  Oban worker for generating recurring tasks.
  Runs daily to create new task instances for recurring tasks.
  """
  use Oban.Worker, queue: :tasks, max_attempts: 3

  import Ecto.Query
  alias AfyaFit.Repo
  alias AfyaFit.Tasks
  alias AfyaFit.Tasks.{Task, TaskRecurrence}

  @impl Oban.Worker
  def perform(_job) do
    today = Date.utc_today()

    # Find all recurring tasks that need new instances generated
    recurring_tasks =
      Task
      |> join(:inner, [t], tr in TaskRecurrence, on: t.id == tr.task_id)
      |> where([t, tr], t.is_recurring == true)
      |> where([t, tr], is_nil(tr.end_date) or tr.end_date >= ^today)
      |> preload([t, tr], [:task_recurrence, :trainer, :client, :organization])
      |> Repo.all()

    Enum.each(recurring_tasks, fn task ->
      generate_recurring_task_instance(task, today)
    end)

    :ok
  end

  defp generate_recurring_task_instance(%Task{} = task, today) do
    recurrence = task.task_recurrence

    cond do
      should_generate_daily?(recurrence, today) ->
        create_task_instance(task, today)

      should_generate_weekly?(recurrence, today) ->
        create_task_instance(task, today)

      should_generate_monthly?(recurrence, today) ->
        create_task_instance(task, today)

      true ->
        :ok
    end
  end

  defp should_generate_daily?(%TaskRecurrence{frequency: "daily", interval: interval}, _today) do
    # Check if we should generate based on interval (every N days)
    # For simplicity, we'll generate daily tasks every day
    # In a production system, you'd track the last generation date
    interval == 1
  end

  defp should_generate_daily?(_recurrence, _today), do: false

  defp should_generate_weekly?(
         %TaskRecurrence{frequency: "weekly", days_of_week: days_of_week},
         today
       ) do
    # Check if today is one of the specified days of week
    # days_of_week is an array of integers (0 = Sunday, 6 = Saturday)
    day_of_week = Date.day_of_week(today, :sunday) - 1
    days_of_week && day_of_week in days_of_week
  end

  defp should_generate_weekly?(_recurrence, _today), do: false

  defp should_generate_monthly?(
         %TaskRecurrence{frequency: "monthly", day_of_month: day_of_month},
         today
       ) do
    # Check if today matches the day of month
    day_of_month && today.day == day_of_month
  end

  defp should_generate_monthly?(_recurrence, _today), do: false

  defp create_task_instance(%Task{} = original_task, due_date) do
    # Check if task instance already exists for this date
    existing_task =
      Task
      |> where([t], t.client_id == ^original_task.client_id)
      |> where([t], t.trainer_id == ^original_task.trainer_id)
      |> where([t], t.title == ^original_task.title)
      |> where([t], fragment("DATE(?)", t.due_date) == ^due_date)
      |> where([t], t.status == "pending")
      |> Repo.one()

    if existing_task do
      :ok
    else
      # Create new task instance
      attrs = %{
        organization_id: original_task.organization_id,
        trainer_id: original_task.trainer_id,
        client_id: original_task.client_id,
        title: original_task.title,
        description: original_task.description,
        task_type: original_task.task_type,
        priority: original_task.priority,
        due_date: DateTime.new!(due_date, ~T[09:00:00], "Etc/UTC"),
        is_recurring: false,
        status: "pending"
      }

      case Tasks.create_task(attrs) do
        {:ok, _task} -> :ok
        {:error, _changeset} -> :error
      end
    end
  end
end
