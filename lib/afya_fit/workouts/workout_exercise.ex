defmodule AfyaFit.Workouts.WorkoutExercise do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "workout_exercises" do
    belongs_to :workout_plan, AfyaFit.Workouts.WorkoutPlan
    belongs_to :exercise, AfyaFit.Workouts.Exercise

    field :exercise_name, :string
    field :sets, :integer
    field :reps, :string
    field :weight, :string
    field :rest_seconds, :integer
    field :video_url, :string
    field :instructions, :string
    field :order_index, :integer
    field :day_number, :integer

    timestamps(updated_at: false, type: :utc_datetime)
  end

  def changeset(workout_exercise, attrs) do
    workout_exercise
    |> cast(attrs, [
      :workout_plan_id,
      :exercise_id,
      :exercise_name,
      :sets,
      :reps,
      :weight,
      :rest_seconds,
      :video_url,
      :instructions,
      :order_index,
      :day_number
    ])
    |> validate_required([:workout_plan_id, :exercise_name, :order_index])
  end
end
