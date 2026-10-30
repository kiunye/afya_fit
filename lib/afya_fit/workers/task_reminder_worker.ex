defmodule AfyaFit.Workers.TaskReminderWorker do
  @moduledoc """
  Oban worker for sending task reminders.
  Runs daily to send reminders for tasks due today or tomorrow.
  """
  use Oban.Worker, queue: :tasks, max_attempts: 3
  use AfyaFit.Repo.Wrap, :job

  import Ecto.Query
  alias AfyaFit.Repo
  alias AfyaFit.Tasks
  alias AfyaFit.Tasks.Task
  alias AfyaFit.Workers.EmailWorker

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()
    # Time zones run from UTC-12 to UTC+14, so this window holds everyone's
    # "today and tomorrow"; each client's own calendar then decides.
    from = DateTime.add(now, -14, :hour)
    until = DateTime.add(now, 62, :hour)

    candidates =
      Task
      |> where([t], t.status == "pending")
      |> where([t], not is_nil(t.due_date))
      |> where([t], t.due_date >= ^from)
      |> where([t], t.due_date <= ^until)
      |> preload([:client, :trainer, :organization])
      |> Repo.all()

    candidates
    |> Enum.filter(&Tasks.due_soon?(&1, now))
    |> Enum.each(&send_task_reminder/1)

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
