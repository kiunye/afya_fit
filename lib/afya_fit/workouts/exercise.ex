defmodule AfyaFit.Workouts.Exercise do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "exercises" do
    field :name, :string
    field :category, :string
    field :muscle_groups, {:array, :string}
    field :equipment_needed, {:array, :string}
    field :description, :string
    field :default_video_url, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(exercise, attrs) do
    exercise
    |> cast(attrs, [
      :name,
      :category,
      :muscle_groups,
      :equipment_needed,
      :description,
      :default_video_url
    ])
    |> validate_required([:name, :category])
    |> unique_constraint(:name)
  end
end
