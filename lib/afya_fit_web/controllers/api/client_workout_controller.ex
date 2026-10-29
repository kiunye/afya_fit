defmodule AfyaFitWeb.API.ClientWorkoutController do
  use AfyaFitWeb, :controller

  alias AfyaFit.{Authorization, Clients, Repo, Workouts}

  # Authentication is handled in router pipeline

  action_fallback AfyaFitWeb.API.FallbackController

  # Who an assignment belongs to, and who made it, cannot be changed through the API.
  @protected_fields ["client_id", "assigned_by"]

  def index(conn, %{"client_id" => client_id}) do
    scope = conn.assigns.current_scope

    with {:ok, _client} <- Clients.fetch_for(scope, :read, client_id),
         :ok <- Authorization.authorize(scope, :list, :client_workout) do
      client_workouts =
        client_id
        |> Workouts.list_client_workouts_by_client()
        |> Repo.preload([:workout_plan, :client])

      json(conn, %{data: Enum.map(client_workouts, &format_client_workout/1)})
    end
  end

  def create(conn, %{"client_id" => client_id, "client_workout" => workout_params}) do
    scope = conn.assigns.current_scope

    attrs =
      workout_params
      |> Map.put("client_id", client_id)
      |> Map.put("assigned_by", scope.user.id)

    with {:ok, _client} <- Clients.fetch_for(scope, :read, client_id),
         :ok <- Authorization.authorize(scope, :create, :client_workout),
         :ok <- authorize_plan(scope, attrs["workout_plan_id"]),
         {:ok, client_workout} <- Workouts.create_client_workout(attrs) do
      client_workout = Repo.preload(client_workout, [:workout_plan, :client])

      conn
      |> put_status(:created)
      |> json(%{data: format_client_workout(client_workout)})
    end
  end

  def update(conn, %{"id" => id, "client_workout" => workout_params}) do
    scope = conn.assigns.current_scope
    attrs = Map.drop(workout_params, @protected_fields)

    with {:ok, client_workout} <- fetch_client_workout(conn, :update, id),
         :ok <- authorize_plan(scope, attrs["workout_plan_id"]),
         {:ok, client_workout} <- Workouts.update_client_workout(client_workout, attrs) do
      client_workout = Repo.preload(client_workout, [:workout_plan, :client])
      json(conn, %{data: format_client_workout(client_workout)})
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, client_workout} <- fetch_client_workout(conn, :delete, id),
         {:ok, _client_workout} <- Workouts.delete_client_workout(client_workout) do
      send_resp(conn, :no_content, "")
    end
  end

  def complete(conn, %{"id" => id}) do
    attrs = %{"status" => "completed", "completed_at" => DateTime.utc_now()}

    with {:ok, client_workout} <- fetch_client_workout(conn, :complete, id),
         {:ok, client_workout} <- Workouts.update_client_workout(client_workout, attrs) do
      client_workout = Repo.preload(client_workout, [:workout_plan, :client])
      json(conn, %{data: format_client_workout(client_workout)})
    end
  end

  # Assignments carry no organization of their own, so the client is preloaded.
  defp fetch_client_workout(conn, action, id) do
    client_workout =
      id |> Workouts.get_client_workout!() |> Repo.preload([:workout_plan, :client])

    with :ok <- Authorization.authorize(conn.assigns.current_scope, action, client_workout) do
      {:ok, client_workout}
    end
  end

  # A plan can only be assigned if the requester may read it.
  defp authorize_plan(_scope, nil), do: :ok

  defp authorize_plan(scope, plan_id) do
    case Repo.get(AfyaFit.Workouts.WorkoutPlan, plan_id) do
      nil -> {:error, :not_found}
      plan -> Authorization.authorize(scope, :read, plan)
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
