defmodule AfyaFit.Tracking.ProgressEntry do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "progress_entries" do
    belongs_to :client, AfyaFit.Accounts.User
    belongs_to :trainer, AfyaFit.Accounts.User

    field :entry_date, :date
    field :weight, :decimal
    field :body_fat_percentage, :decimal
    field :notes, :string

    has_many :progress_measurements, AfyaFit.Tracking.ProgressMeasurement
    has_many :progress_photos, AfyaFit.Tracking.ProgressPhoto

    timestamps(type: :utc_datetime)
  end

  def changeset(progress_entry, attrs) do
    progress_entry
    |> cast(attrs, [:client_id, :trainer_id, :entry_date, :weight, :body_fat_percentage, :notes])
    |> validate_required([:client_id, :trainer_id, :entry_date])
    |> unique_constraint([:client_id, :entry_date])
  end
end
