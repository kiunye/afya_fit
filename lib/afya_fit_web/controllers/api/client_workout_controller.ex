defmodule AfyaFitWeb.API.ClientWorkoutController do
  use AfyaFitWeb, :controller

  alias AfyaFit.Workouts
  alias AfyaFit.Clients
  alias AfyaFit.Repo

  # Authentication is handled in router pipeline

  action_fallback AfyaFitWeb.API.FallbackController

  def index(conn, %{"client_id" => client_id}) do
    current_user = conn.assigns.current_user

    # Verify client access
    Clients.get_client!(current_user, client_id)

    client_workouts =
      Workouts.list_client_workouts_by_client(client_id)
      |> Enum.filter(fn cw ->
        # Load workout plan to check organization
        cw = Repo.preload(cw, :workout_plan)
        cw.workout_plan.organization_id == current_user.organization_id
      end)
      |> Repo.preload([:workout_plan, :client])

    json(conn, %{data: Enum.map(client_workouts, &format_client_workout/1)})
  end

  def create(conn, %{"client_id" => client_id, "client_workout" => workout_params}) do
    current_user = conn.assigns.current_user

    # Verify client access
    Clients.get_client!(current_user, client_id)

    attrs =
      workout_params
      |> Map.put("client_id", client_id)
      |> Map.put("assigned_by", current_user.id)

    case Workouts.create_client_workout(attrs) do
      {:ok, client_workout} ->
        client_workout =
          client_workout
          |> Repo.preload([:workout_plan, :client])

        conn
        |> put_status(:created)
        |> json(%{data: format_client_workout(client_workout)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"422", changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "client_workout" => workout_params}) do
    current_user = conn.assigns.current_user
    client_workout = Workouts.get_client_workout!(id)

    # Verify access via workout plan organization
    client_workout = Repo.preload(client_workout, :workout_plan)

    if client_workout.workout_plan.organization_id == current_user.organization_id &&
         (client_workout.assigned_by == current_user.id || current_user.role == "admin") do
      case Workouts.update_client_workout(client_workout, workout_params) do
        {:ok, client_workout} ->
          client_workout = Repo.preload(client_workout, [:workout_plan, :client])
          json(conn, %{data: format_client_workout(client_workout)})

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(AfyaFitWeb.API.ErrorView)
          |> render(:"422", changeset: changeset)
      end
    else
      conn
      |> put_status(:forbidden)
      |> put_view(AfyaFitWeb.API.ErrorView)
      |> render(:"403")
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    client_workout = Workouts.get_client_workout!(id)

    # Verify access
    client_workout = Repo.preload(client_workout, :workout_plan)

    if client_workout.workout_plan.organization_id == current_user.organization_id &&
         (client_workout.assigned_by == current_user.id || current_user.role == "admin") do
      Workouts.delete_client_workout(client_workout)
      send_resp(conn, :no_content, "")
    else
      conn
      |> put_status(:forbidden)
      |> put_view(AfyaFitWeb.API.ErrorView)
      |> render(:"403")
    end
  end

  def complete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    client_workout = Workouts.get_client_workout!(id)

    # Verify access - clients can complete their own workouts, trainers can mark any as complete
    client_workout = Repo.preload(client_workout, :workout_plan)

    if client_workout.workout_plan.organization_id == current_user.organization_id &&
         (client_workout.client_id == current_user.id ||
            client_workout.assigned_by == current_user.id || current_user.role == "admin") do
      attrs = %{
        "status" => "completed",
        "completed_at" => DateTime.utc_now()
      }

      case Workouts.update_client_workout(client_workout, attrs) do
        {:ok, client_workout} ->
          client_workout = Repo.preload(client_workout, [:workout_plan, :client])
          json(conn, %{data: format_client_workout(client_workout)})

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(AfyaFitWeb.API.ErrorView)
          |> render(:"422", changeset: changeset)
      end
    else
      conn
      |> put_status(:forbidden)
      |> put_view(AfyaFitWeb.API.ErrorView)
      |> render(:"403")
    end
  end

  defp format_client_workout(%{id: id} = cw) do
    %{
      id: id,
      client_id: cw.client_id,
      workout_plan_id: cw.workout_plan_id,
      assigned_by: cw.assigned_by,
      assigned_date: cw.assigned_date,
      start_date: cw.start_date,
      end_date: cw.end_date,
      status: cw.status,
      completed_at: cw.completed_at,
      notes: cw.notes,
      inserted_at: cw.inserted_at,
      updated_at: cw.updated_at
    }
  end
end
