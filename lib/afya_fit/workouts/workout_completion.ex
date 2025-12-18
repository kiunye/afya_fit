defmodule AfyaFit.Workouts.WorkoutCompletion do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "workout_completions" do
    belongs_to :client_workout, AfyaFit.Workouts.ClientWorkout

    field :completed_date, :date
    field :duration_minutes, :integer
    field :notes, :string
    field :rating, :integer

    timestamps(updated_at: false, type: :utc_datetime)
  end

  def changeset(workout_completion, attrs) do
    workout_completion
    |> cast(attrs, [:client_workout_id, :completed_date, :duration_minutes, :notes, :rating])
    |> validate_required([:client_workout_id, :completed_date])
    |> validate_inclusion(:rating, 1..5)
  end
end
