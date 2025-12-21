defmodule AfyaFit.Accounts.UserPreference do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_preferences" do
    belongs_to :user, AfyaFit.Accounts.User

    field :notification_preferences, :map
    field :dashboard_preferences, :map
    field :language, :string, default: "en"
    field :theme, :string, default: "light"

    timestamps(type: :utc_datetime)
  end

  def changeset(prefs, attrs) do
    prefs
    |> cast(attrs, [
      :user_id,
      :notification_preferences,
      :dashboard_preferences,
      :language,
      :theme
    ])
    |> validate_required([:user_id])
    |> validate_inclusion(:theme, ["light", "dark"])
  end
end
