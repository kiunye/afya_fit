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

  @ownership [:client_id, :trainer_id]

  @doc """
  Changeset for editing an existing record: the same rules as `changeset/2`,
  but ownership fields (`:client_id, :trainer_id`) can never change.
  """
  def update_changeset(progress_entry, attrs),
    do: changeset(progress_entry, AfyaFit.Ownership.without(attrs, @ownership))
end
