defmodule AfyaFit.Organizations.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "organizations" do
    field :name, :string
    field :subdomain, :string
    field :plan_type, :string, default: "free"
    field :status, :string, default: "active"
    field :branding_config, :map, default: %{}
    field :settings, :map, default: %{}
    field :deleted_at, :utc_datetime

    has_many :users, AfyaFit.Accounts.User
    # Add other has_many relationships as modules are created

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [
      :name,
      :subdomain,
      :plan_type,
      :status,
      :branding_config,
      :settings,
      :deleted_at
    ])
    |> validate_required([:name, :subdomain, :plan_type, :status])
    |> validate_length(:subdomain, min: 2, max: 100)
    |> validate_format(:subdomain, ~r/^[a-z0-9-]+$/)
    |> validate_inclusion(:plan_type, ["free", "pro", "enterprise"])
    |> validate_inclusion(:status, ["active", "suspended", "cancelled"])
    |> unsafe_validate_unique(:subdomain, AfyaFit.Repo)
    |> unique_constraint(:subdomain)
  end
end
