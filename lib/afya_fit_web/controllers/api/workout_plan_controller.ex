defmodule AfyaFitWeb.API.WorkoutPlanController do
  use AfyaFitWeb, :controller

  alias AfyaFit.Workouts

  # Authentication is handled in router pipeline

  action_fallback AfyaFitWeb.API.FallbackController

  def index(conn, _params) do
    current_user = conn.assigns.current_user

    workout_plans =
      Workouts.list_workout_plans()
      |> Enum.filter(fn plan ->
        plan.organization_id == current_user.organization_id &&
          (plan.trainer_id == current_user.id || plan.is_public || current_user.role == "admin")
      end)

    render(conn, :index, workout_plans: workout_plans)
  end

  def create(conn, %{"workout_plan" => workout_plan_params}) do
    current_user = conn.assigns.current_user

    attrs =
      workout_plan_params
      |> Map.put("organization_id", current_user.organization_id)
      |> Map.put("trainer_id", current_user.id)

    case Workouts.create_workout_plan(attrs) do
      {:ok, workout_plan} ->
        conn
        |> put_status(:created)
        |> render(:show, workout_plan: workout_plan)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"422", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    workout_plan = Workouts.get_workout_plan!(id)

    # Verify access
    if workout_plan.organization_id == current_user.organization_id &&
         (workout_plan.trainer_id == current_user.id || workout_plan.is_public ||
            current_user.role == "admin") do
      render(conn, :show, workout_plan: workout_plan)
    else
      conn
      |> put_status(:forbidden)
      |> put_view(AfyaFitWeb.API.ErrorView)
      |> render(:"403")
    end
  end

  def update(conn, %{"id" => id, "workout_plan" => workout_plan_params}) do
    current_user = conn.assigns.current_user
    workout_plan = Workouts.get_workout_plan!(id)

    # Verify ownership
    if workout_plan.trainer_id == current_user.id || current_user.role == "admin" do
      case Workouts.update_workout_plan(workout_plan, workout_plan_params) do
        {:ok, workout_plan} ->
          render(conn, :show, workout_plan: workout_plan)

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
    workout_plan = Workouts.get_workout_plan!(id)

    # Verify ownership
    if workout_plan.trainer_id == current_user.id || current_user.role == "admin" do
      Workouts.delete_workout_plan(workout_plan)
      send_resp(conn, :no_content, "")
    else
      conn
      |> put_status(:forbidden)
      |> put_view(AfyaFitWeb.API.ErrorView)
      |> render(:"403")
    end
  end

  def duplicate(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    original_plan = Workouts.get_workout_plan!(id)

    # Verify access
    if original_plan.organization_id == current_user.organization_id do
      attrs = %{
        "name" => "#{original_plan.name} (Copy)",
        "description" => original_plan.description,
        "duration_weeks" => original_plan.duration_weeks,
        "difficulty" => original_plan.difficulty,
        "organization_id" => current_user.organization_id,
        "trainer_id" => current_user.id,
        "is_template" => false
      }

      case Workouts.create_workout_plan(attrs) do
        {:ok, workout_plan} ->
          conn
          |> put_status(:created)
          |> render(:show, workout_plan: workout_plan)

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

  def templates(conn, _params) do
    current_user = conn.assigns.current_user

    templates =
      Workouts.list_workout_plans()
      |> Enum.filter(fn plan ->
        plan.organization_id == current_user.organization_id && plan.is_template
      end)

    render(conn, :index, workout_plans: templates)
  end
end
