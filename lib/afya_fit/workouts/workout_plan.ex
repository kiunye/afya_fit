defmodule AfyaFit.Workouts.WorkoutPlan do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "workout_plans" do
    belongs_to :organization, AfyaFit.Organizations.Organization
    belongs_to :trainer, AfyaFit.Accounts.User

    field :name, :string
    field :description, :string
    field :duration_weeks, :integer
    field :difficulty, :string
    field :is_template, :boolean, default: false
    field :is_public, :boolean, default: false
    field :deleted_at, :utc_datetime

    has_many :workout_exercises, AfyaFit.Workouts.WorkoutExercise
    # has_many :workout_plan_tags, AfyaFit.Tags.WorkoutPlanTag

    timestamps(type: :utc_datetime)
  end

  def changeset(workout_plan, attrs) do
    workout_plan
    |> cast(attrs, [
      :organization_id,
      :trainer_id,
      :name,
      :description,
      :duration_weeks,
      :difficulty,
      :is_template,
      :is_public,
      :deleted_at
    ])
    |> validate_required([:organization_id, :trainer_id, :name])
    |> validate_inclusion(:difficulty, ["beginner", "intermediate", "advanced"])
  end
end
