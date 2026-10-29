defmodule AfyaFit.Schedule.CalendarEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "calendar_events" do
    belongs_to :organization, AfyaFit.Organizations.Organization
    belongs_to :user, AfyaFit.Accounts.User

    field :title, :string
    field :description, :string
    field :event_type, :string
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :is_all_day, :boolean, default: false
    field :timezone, :string
    field :location, :string
    field :related_id, :binary_id
    field :related_type, :string

    has_many :calendar_event_attendees, AfyaFit.Schedule.CalendarEventAttendee,
      foreign_key: :event_id

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :organization_id,
      :user_id,
      :title,
      :description,
      :event_type,
      :start_time,
      :end_time,
      :is_all_day,
      :timezone,
      :location,
      :related_id,
      :related_type
    ])
    |> validate_required([:organization_id, :user_id, :title, :event_type, :start_time])
    |> validate_inclusion(:event_type, ["workout", "nutrition", "task", "appointment", "custom"])
  end

  @ownership [:organization_id, :user_id]

  @doc """
  Changeset for editing an existing record: the same rules as `changeset/2`,
  but ownership fields (`:organization_id, :user_id`) can never change.
  """
  def update_changeset(event, attrs),
    do: changeset(event, AfyaFit.Ownership.without(attrs, @ownership))
end
