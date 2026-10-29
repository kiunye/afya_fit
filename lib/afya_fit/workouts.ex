defmodule AfyaFit.Workouts do
  @moduledoc """
  The Workouts context.
  """
  import Ecto.Query, warn: false
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Repo

  alias AfyaFit.Workouts.{
    ClientWorkout,
    Exercise,
    WorkoutCompletion,
    WorkoutExercise,
    WorkoutPlan
  }

  # WORKOUT PLANS

  def list_workout_plans do
    Repo.all(WorkoutPlan)
  end

  @doc """
  Lists the workout plans the scope's user may read: every plan for platform
  admins, the organization's plans for organization admins, and for trainers
  their own plus the organization's public and template plans.
  """
  def list_workout_plans_for(%Scope{user: user} = scope) do
    case Scope.role(scope) do
      :admin ->
        Repo.all(WorkoutPlan)

      :org_admin ->
        Repo.all(from p in WorkoutPlan, where: p.organization_id == ^user.organization_id)

      :trainer ->
        Repo.all(
          from p in WorkoutPlan,
            where:
              p.organization_id == ^user.organization_id and
                (p.trainer_id == ^user.id or p.is_public or p.is_template)
        )

      _ ->
        []
    end
  end

  @doc "Lists the organization's template plans."
  def list_workout_templates_for(%Scope{user: user}) do
    Repo.all(
      from p in WorkoutPlan,
        where: p.organization_id == ^user.organization_id and p.is_template
    )
  end

  def get_workout_plan!(id), do: Repo.get!(WorkoutPlan, id)

  @doc "Gets a workout plan, or `nil`."
  def get_workout_plan(id), do: Repo.get(WorkoutPlan, id)

  def create_workout_plan(attrs \\ %{}) do
    %WorkoutPlan{}
    |> WorkoutPlan.changeset(attrs)
    |> Repo.insert()
  end

  def update_workout_plan(%WorkoutPlan{} = workout_plan, attrs) do
    workout_plan
    |> WorkoutPlan.changeset(attrs)
    |> Repo.update()
  end

  def delete_workout_plan(%WorkoutPlan{} = workout_plan) do
    Repo.delete(workout_plan)
  end

  def change_workout_plan(%WorkoutPlan{} = workout_plan, attrs \\ %{}) do
    WorkoutPlan.changeset(workout_plan, attrs)
  end

  # EXERCISES

  def list_exercises do
    Repo.all(Exercise)
  end

  def get_exercise!(id), do: Repo.get!(Exercise, id)

  def create_exercise(attrs \\ %{}) do
    %Exercise{}
    |> Exercise.changeset(attrs)
    |> Repo.insert()
  end

  def update_exercise(%Exercise{} = exercise, attrs) do
    exercise
    |> Exercise.changeset(attrs)
    |> Repo.update()
  end

  def delete_exercise(%Exercise{} = exercise) do
    Repo.delete(exercise)
  end

  def change_exercise(%Exercise{} = exercise, attrs \\ %{}) do
    Exercise.changeset(exercise, attrs)
  end

  # CLIENT WORKOUTS

  def list_client_workouts do
    Repo.all(ClientWorkout)
  end

  def list_client_workouts_by_client(client_id) do
    ClientWorkout
    |> where([cw], cw.client_id == ^client_id)
    |> Repo.all()
  end

  def get_client_workout!(id), do: Repo.get!(ClientWorkout, id)

  def create_client_workout(attrs \\ %{}) do
    %ClientWorkout{}
    |> ClientWorkout.changeset(attrs)
    |> Repo.insert()
  end

  def update_client_workout(%ClientWorkout{} = client_workout, attrs) do
    client_workout
    |> ClientWorkout.changeset(attrs)
    |> Repo.update()
  end

  def delete_client_workout(%ClientWorkout{} = client_workout) do
    Repo.delete(client_workout)
  end

  # WORKOUT EXERCISES (Junction)
  def create_workout_exercise(attrs \\ %{}) do
    %WorkoutExercise{}
    |> WorkoutExercise.changeset(attrs)
    |> Repo.insert()
  end

  # WORKOUT COMPLETIONS
  def create_workout_completion(attrs \\ %{}) do
    %WorkoutCompletion{}
    |> WorkoutCompletion.changeset(attrs)
    |> Repo.insert()
  end
end
