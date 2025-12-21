defmodule AfyaFit.Dashboard do
  @moduledoc """
  Dashboard context for aggregating statistics and overview data.
  """
  import Ecto.Query, warn: false
  alias AfyaFit.{Clients, Workouts, Nutrition, Tasks, Schedule}

  @doc """
  Gets dashboard statistics for a trainer.
  """
  def get_trainer_stats(trainer) do
    %{
      total_clients: count_active_clients(trainer.id),
      total_workout_plans: count_workout_plans(trainer),
      total_nutrition_plans: count_nutrition_plans(trainer),
      active_tasks: count_active_tasks(trainer),
      upcoming_events: count_upcoming_events(trainer.id),
      recent_progress_entries: count_recent_progress(trainer.id)
    }
  end

  @doc """
  Gets recent activity for a trainer (clients, workouts, progress, etc.)
  """
  def get_recent_activity(trainer) do
    %{
      recent_clients: get_recent_clients(trainer.id, 5),
      recent_workouts: get_recent_workouts(trainer, 5),
      recent_progress: get_recent_progress_entries(trainer.id, 5)
    }
  end

  defp count_active_clients(trainer_id) do
    Clients.list_trainer_clients(trainer_id, %{status: "active"})
    |> length()
  end

  defp count_workout_plans(trainer) do
    Workouts.list_workout_plans()
    |> Enum.filter(fn plan ->
      plan.organization_id == trainer.organization_id &&
        plan.trainer_id == trainer.id
    end)
    |> length()
  end

  defp count_nutrition_plans(trainer) do
    Nutrition.list_nutrition_plans()
    |> Enum.filter(fn plan ->
      plan.organization_id == trainer.organization_id &&
        plan.trainer_id == trainer.id
    end)
    |> length()
  end

  defp count_active_tasks(trainer) do
    Tasks.list_tasks()
    |> Enum.filter(fn task ->
      task.organization_id == trainer.organization_id &&
        task.trainer_id == trainer.id &&
        task.status in ["pending", "in_progress"]
    end)
    |> length()
  end

  defp count_upcoming_events(user_id) do
    now = DateTime.utc_now()
    cutoff = DateTime.add(now, 7, :day)

    Schedule.list_calendar_events(user_id)
    |> Enum.filter(fn event ->
      DateTime.compare(event.start_time, now) != :lt &&
        DateTime.compare(event.start_time, cutoff) != :gt
    end)
    |> length()
  end

  defp count_recent_progress(_trainer_id) do
    # Get all progress entries for trainer's clients
    # This is a simplified version - in production you'd want to join properly
    0
  end

  defp get_recent_clients(trainer_id, limit) do
    Clients.list_trainer_clients(trainer_id, %{status: "active"})
    |> Enum.take(limit)
    |> Enum.map(& &1.client)
  end

  defp get_recent_workouts(trainer, limit) do
    Workouts.list_workout_plans()
    |> Enum.filter(fn plan ->
      plan.organization_id == trainer.organization_id &&
        plan.trainer_id == trainer.id
    end)
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
    |> Enum.take(limit)
  end

  defp get_recent_progress_entries(_trainer_id, _limit) do
    # Simplified - would need proper joins in production
    []
  end
end
