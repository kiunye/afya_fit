defmodule AfyaFitWeb.API.WorkoutPlanController do
  use AfyaFitWeb, :controller

  alias AfyaFit.Authorization
  alias AfyaFit.Workouts

  # Authentication is handled in router pipeline

  action_fallback AfyaFitWeb.API.FallbackController

  def index(conn, _params) do
    scope = conn.assigns.current_scope

    with :ok <- Authorization.authorize(scope, :list, :workout_plan) do
      render(conn, :index, workout_plans: Workouts.list_workout_plans_for(scope))
    end
  end

  def create(conn, %{"workout_plan" => workout_plan_params}) do
    scope = conn.assigns.current_scope

    attrs =
      workout_plan_params
      |> Map.put("organization_id", scope.user.organization_id)
      |> Map.put("trainer_id", scope.user.id)

    with :ok <- Authorization.authorize(scope, :create, :workout_plan),
         {:ok, workout_plan} <- Workouts.create_workout_plan(attrs) do
      conn
      |> put_status(:created)
      |> render(:show, workout_plan: workout_plan)
    end
  end

  def show(conn, %{"id" => id}) do
    workout_plan = Workouts.get_workout_plan!(id)

    with :ok <- Authorization.authorize(conn.assigns.current_scope, :read, workout_plan) do
      render(conn, :show, workout_plan: workout_plan)
    end
  end

  def update(conn, %{"id" => id, "workout_plan" => workout_plan_params}) do
    workout_plan = Workouts.get_workout_plan!(id)

    with :ok <- Authorization.authorize(conn.assigns.current_scope, :update, workout_plan),
         {:ok, workout_plan} <- Workouts.update_workout_plan(workout_plan, workout_plan_params) do
      render(conn, :show, workout_plan: workout_plan)
    end
  end

  def delete(conn, %{"id" => id}) do
    workout_plan = Workouts.get_workout_plan!(id)

    with :ok <- Authorization.authorize(conn.assigns.current_scope, :delete, workout_plan),
         {:ok, _workout_plan} <- Workouts.delete_workout_plan(workout_plan) do
      send_resp(conn, :no_content, "")
    end
  end

  def duplicate(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope
    original_plan = Workouts.get_workout_plan!(id)

    attrs = %{
      "name" => "#{original_plan.name} (Copy)",
      "description" => original_plan.description,
      "duration_weeks" => original_plan.duration_weeks,
      "difficulty" => original_plan.difficulty,
      "organization_id" => scope.user.organization_id,
      "trainer_id" => scope.user.id,
      "is_template" => false
    }

    with :ok <- Authorization.authorize(scope, :duplicate, original_plan),
         :ok <- Authorization.authorize(scope, :create, :workout_plan),
         {:ok, workout_plan} <- Workouts.create_workout_plan(attrs) do
      conn
      |> put_status(:created)
      |> render(:show, workout_plan: workout_plan)
    end
  end

  def templates(conn, _params) do
    scope = conn.assigns.current_scope

    with :ok <- Authorization.authorize(scope, :list, :workout_plan) do
      render(conn, :index, workout_plans: Workouts.list_workout_templates_for(scope))
    end
  end
end
