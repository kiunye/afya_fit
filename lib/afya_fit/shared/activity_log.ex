defmodule AfyaFit.Shared.ActivityLog do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "activity_logs" do
    belongs_to :organization, AfyaFit.Organizations.Organization
    belongs_to :user, AfyaFit.Accounts.User

    field :action, :string
    field :resource_type, :string
    field :resource_id, :binary_id
    field :metadata, :map
    # Postgrex.Inet struct
    field :ip_address, :map
    field :user_agent, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :organization_id,
      :user_id,
      :action,
      :resource_type,
      :resource_id,
      :metadata,
      :ip_address,
      :user_agent
    ])
    |> validate_required([:organization_id, :action])
  end
end
