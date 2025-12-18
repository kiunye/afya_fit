defmodule AfyaFit.Schedule.CalendarEventAttendee do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "calendar_event_attendees" do
    belongs_to :event, AfyaFit.Schedule.CalendarEvent
    belongs_to :user, AfyaFit.Accounts.User

    field :status, :string, default: "accepted"

    timestamps(updated_at: false, type: :utc_datetime)
  end

  def changeset(attendee, attrs) do
    attendee
    |> cast(attrs, [:event_id, :user_id, :status])
    |> validate_required([:event_id, :user_id])
    |> validate_inclusion(:status, ["accepted", "declined", "tentative"])
    |> unique_constraint([:event_id, :user_id])
  end
end
