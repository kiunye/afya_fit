defmodule AfyaFitWeb.API.MeController do
  use AfyaFitWeb, :controller

  alias AfyaFit.{Accounts, Billing, Clients, Tracking, Workouts}

  # Authentication is handled in router pipeline

  action_fallback AfyaFitWeb.API.FallbackController

  @doc """
  Get current user's assigned workouts.
  """
  def workouts(conn, _params) do
    current_user = conn.assigns.current_user

    client_workouts =
      Workouts.list_client_workouts_by_client(current_user.id)
      |> Enum.filter(fn cw ->
        # Load workout plan to check organization
        cw = AfyaFit.Repo.preload(cw, :workout_plan)
        cw.workout_plan.organization_id == current_user.organization_id
      end)
      |> AfyaFit.Repo.preload([:workout_plan])

    json(conn, %{data: Enum.map(client_workouts, &format_client_workout/1)})
  end

  @doc """
  Get current user's assigned nutrition plans.
  """
  def nutrition(conn, _params) do
    current_user = conn.assigns.current_user

    nutrition_plans =
      Clients.get_client_nutrition_plans(current_user.id)
      |> Enum.filter(fn plan ->
        plan.organization_id == current_user.organization_id
      end)

    render(conn, :index, nutrition_plans: nutrition_plans)
  end

  @doc """
  Get current user's progress entries.
  """
  def progress(conn, _params) do
    current_user = conn.assigns.current_user
    progress_entries = Tracking.list_progress_entries(current_user.id)

    render(conn, :index, progress_entries: progress_entries)
  end

  @doc """
  Create a progress entry for current user.
  """
  def create_progress(conn, %{"progress_entry" => progress_params}) do
    current_user = conn.assigns.current_user

    # For clients, we need to find their trainer
    trainer_id =
      case current_user.role do
        "client" ->
          # Find active trainer-client relationship for this client
          case Repo.get_by(TrainerClient, client_id: current_user.id, status: "active") do
            nil -> current_user.id
            trainer_client -> trainer_client.trainer_id
          end

        _ ->
          current_user.id
      end

    attrs =
      progress_params
      |> Map.put("client_id", current_user.id)
      |> Map.put("trainer_id", trainer_id)

    case Tracking.create_progress_entry(attrs) do
      {:ok, progress_entry} ->
        conn
        |> put_status(:created)
        |> render(:show, progress_entry: progress_entry)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"422", changeset: changeset)
    end
  end

  @doc """
  Get current user's subscription.
  """
  def subscription(conn, _params) do
    current_user = conn.assigns.current_user

    case Billing.get_client_subscription_by_client(current_user.id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "No subscription found"})

      subscription ->
        json(conn, %{data: format_client_subscription(subscription)})
    end
  end

  @doc """
  Update current user's subscription reminder preferences.
  """
  def update_subscription_reminders(conn, %{"reminder_preferences" => reminder_prefs}) do
    current_user = conn.assigns.current_user

    case Billing.get_client_subscription_by_client(current_user.id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "No subscription found"})

      subscription ->
        case Billing.update_client_subscription_reminders(subscription, reminder_prefs) do
          {:ok, updated_subscription} ->
            json(conn, %{data: format_client_subscription(updated_subscription)})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_view(AfyaFitWeb.API.ErrorView)
            |> render(:"422", changeset: changeset)
        end
    end
  end

  @doc """
  Get current user's tasks.
  """
  def tasks(conn, _params) do
    current_user = conn.assigns.current_user
    tasks = AfyaFit.Tasks.list_tasks(current_user.id)

    render(conn, :index, tasks: tasks)
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
      workout_plan: format_workout_plan(cw.workout_plan),
      inserted_at: cw.inserted_at,
      updated_at: cw.updated_at
    }
  end

  defp format_workout_plan(nil), do: nil

  defp format_workout_plan(plan) do
    %{
      id: plan.id,
      name: plan.name,
      description: plan.description,
      difficulty: plan.difficulty,
      duration_weeks: plan.duration_weeks
    }
  end

  defp format_client_subscription(subscription) do
    %{
      id: subscription.id,
      client_id: subscription.client_id,
      organization_id: subscription.organization_id,
      plan_type: subscription.plan_type,
      status: subscription.status,
      current_period_start: subscription.current_period_start,
      current_period_end: subscription.current_period_end,
      cancel_at_period_end: subscription.cancel_at_period_end,
      cancelled_at: subscription.cancelled_at,
      reminder_preferences: subscription.reminder_preferences || %{},
      inserted_at: subscription.inserted_at,
      updated_at: subscription.updated_at
    }
  end
end
