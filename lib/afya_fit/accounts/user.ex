defmodule AfyaFit.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :role, :string
    field :first_name, :string
    field :last_name, :string
    field :phone, :string
    field :avatar_url, :string
    field :timezone, :string, default: "UTC"
    field :email_verified, :boolean, default: false
    field :email_verified_at, :utc_datetime
    field :last_login_at, :utc_datetime
    field :deleted_at, :utc_datetime

    belongs_to :organization, AfyaFit.Organizations.Organization

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :email,
      :password,
      :password_hash,
      :role,
      :first_name,
      :last_name,
      :phone,
      :avatar_url,
      :timezone,
      :organization_id
    ])
    |> validate_required([:email, :role, :first_name, :last_name, :organization_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, AfyaFit.Repo)
    |> unique_constraint(:email)
    |> validate_inclusion(:role, ["trainer", "client", "admin"])
  end
end
