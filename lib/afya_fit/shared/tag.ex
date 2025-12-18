defmodule AfyaFit.Shared.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tags" do
    belongs_to :organization, AfyaFit.Organizations.Organization
    field :name, :string
    field :color, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:organization_id, :name, :color])
    |> validate_required([:name])
    |> unique_constraint([:organization_id, :name])
  end
end
