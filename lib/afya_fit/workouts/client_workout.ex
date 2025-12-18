defmodule AfyaFit.Workouts.ClientWorkout do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "client_workouts" do
    belongs_to :client, AfyaFit.Accounts.User
    belongs_to :workout_plan, AfyaFit.Workouts.WorkoutPlan
    belongs_to :assigner, AfyaFit.Accounts.User, foreign_key: :assigned_by

    field :assigned_date, :date
    field :start_date, :date
    field :end_date, :date
    field :status, :string, default: "assigned"
    field :completed_at, :utc_datetime
    field :notes, :string

    has_one :workout_completion, AfyaFit.Workouts.WorkoutCompletion

    timestamps(type: :utc_datetime)
  end

  def changeset(client_workout, attrs) do
    client_workout
    |> cast(attrs, [
      :client_id,
      :workout_plan_id,
      :assigned_by,
      :assigned_date,
      :start_date,
      :end_date,
      :status,
      :completed_at,
      :notes
    ])
    |> validate_required([
      :client_id,
      :workout_plan_id,
      :assigned_by,
      :assigned_date,
      :start_date,
      :status
    ])
    |> validate_inclusion(:status, ["assigned", "in_progress", "completed", "skipped"])
  end
end
