defmodule AfyaFitWeb.ClientLive.Home do
  @moduledoc """
  Home for clients: the workouts and tasks their trainer has assigned.
  """
  use AfyaFitWeb, :live_view

  import AfyaFitWeb.SignComponents

  alias AfyaFit.{Repo, Tasks, Workouts}
  alias AfyaFitWeb.Access

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> Access.guard(:list, :client_workout)
      |> assign(:page_title, "Home")

    if socket.assigns.denied do
      {:ok, socket}
    else
      user = socket.assigns.current_scope.user

      workouts =
        user.id
        |> Workouts.list_client_workouts_by_client()
        |> Repo.preload(:workout_plan)
        |> Enum.reject(&(&1.status == "completed"))
        |> Enum.sort_by(& &1.start_date, {:asc, Date})

      tasks =
        user.id
        |> Tasks.list_tasks()
        |> Enum.filter(&(&1.status in ["pending", "in_progress"]))
        |> Enum.sort_by(&(&1.due_date || ~U[2999-01-01 00:00:00Z]), {:asc, DateTime})

      {:ok,
       socket
       |> assign(:count, length(workouts) + length(tasks))
       |> stream(:workouts, workouts)
       |> stream(:tasks, tasks)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:home}>
      <.denied_sign :if={@denied} kind={elem(@denied, 0)} message={elem(@denied, 1)} />

      <div :if={!@denied} id="home">
        <.page_header>
          Home
          <:subtitle>
            <b class="text-ink">
              {if @count == 0, do: "Nothing assigned yet.", else: "#{@count} to do."}
            </b>
            Your plan for this week.
          </:subtitle>
        </.page_header>

        <.sign_group label="Workouts">
          <div id="workouts" phx-update="stream">
            <div id="workouts-empty" class="hidden px-4 py-6 text-ink-2 only:block sm:px-[26px]">
              Your trainer has not assigned a workout yet.
            </div>
            <.sign
              :for={{id, cw} <- @streams.workouts}
              id={id}
              icon={:workouts}
              time={Calendar.strftime(cw.start_date, "%-d %b")}
              time_label="Starts"
            >
              <:title>{cw.workout_plan.name}</:title>
              {String.capitalize(cw.status)}
            </.sign>
          </div>
        </.sign_group>

        <.sign_group label="Tasks">
          <div id="tasks" phx-update="stream">
            <div id="tasks-empty" class="hidden px-4 py-6 text-ink-2 only:block sm:px-[26px]">
              No tasks right now.
            </div>
            <.sign
              :for={{id, task} <- @streams.tasks}
              id={id}
              icon={:alert}
              draw={false}
              time={local(task.due_date, @current_scope, "%-d %b")}
              time_label={task.due_date && "Due"}
            >
              <:title>{task.title}</:title>
              {task.description}
            </.sign>
          </div>
        </.sign_group>
      </div>
    </Layouts.app>
    """
  end
end
