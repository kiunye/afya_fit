defmodule AfyaFit.Tracking.ProgressPhoto do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "progress_photos" do
    belongs_to :progress_entry, AfyaFit.Tracking.ProgressEntry

    field :photo_type, :string
    field :url, :string
    field :thumbnail_url, :string
    field :order_index, :integer, default: 0

    timestamps(updated_at: false, type: :utc_datetime)
  end

  def changeset(photo, attrs) do
    photo
    |> cast(attrs, [:progress_entry_id, :photo_type, :url, :thumbnail_url, :order_index])
    |> validate_required([:progress_entry_id, :photo_type, :url])
    |> validate_inclusion(:photo_type, ["front", "side", "back", "full_body"])
  end
end
