defmodule AfyaFit.Tracking.ProgressMeasurement do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "progress_measurements" do
    belongs_to :progress_entry, AfyaFit.Tracking.ProgressEntry

    field :measurement_type, :string
    field :value, :decimal
    field :unit, :string, default: "cm"

    timestamps(updated_at: false, type: :utc_datetime)
  end

  def changeset(measurement, attrs) do
    measurement
    |> cast(attrs, [:progress_entry_id, :measurement_type, :value, :unit])
    |> validate_required([:progress_entry_id, :measurement_type, :value])
  end
end
