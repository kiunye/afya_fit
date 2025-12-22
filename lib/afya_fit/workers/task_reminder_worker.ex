defmodule AfyaFit.Workers.TaskReminderWorker do
  @moduledoc """
  Oban worker for sending task reminders.
  Runs daily to send reminders for tasks due today or tomorrow.
  """
  use Oban.Worker, queue: :tasks, max_attempts: 3

  import Ecto.Query
  alias AfyaFit.Repo
  alias AfyaFit.Tasks.Task
  alias AfyaFit.Workers.EmailWorker

  @impl Oban.Worker
  def perform(_job) do
    today = DateTime.new!(Date.utc_today(), ~T[00:00:00], "Etc/UTC")
    tomorrow = DateTime.add(today, 1, :day)

    # Find tasks due today or tomorrow that are pending
    tasks_due_soon =
      Task
      |> where([t], t.status == "pending")
      |> where([t], not is_nil(t.due_date))
      |> where([t], t.due_date >= ^today)
      |> where([t], t.due_date <= ^tomorrow)
      |> preload([:client, :trainer, :organization])
      |> Repo.all()

    Enum.each(tasks_due_soon, fn task ->
      send_task_reminder(task)
    end)

    :ok
  end

  defp send_task_reminder(%Task{client: client} = task) when not is_nil(client) do
    %{
      "email_module" => "AfyaFitWeb.TaskEmail",
      "email_function" => "task_reminder",
      "args" => [client, task]
    }
    |> EmailWorker.new()
    |> Oban.insert()
  end

  defp send_task_reminder(_task), do: :ok
end
