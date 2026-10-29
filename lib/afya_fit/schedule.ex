defmodule AfyaFit.Schedule do
  @moduledoc """
  The Schedule context.
  """
  import Ecto.Query, warn: false
  alias AfyaFit.Repo
  alias AfyaFit.Schedule.{CalendarEvent, CalendarEventAttendee}

  def list_calendar_events(user_id) do
    CalendarEvent
    |> where([e], e.user_id == ^user_id)
    |> Repo.all()
  end

  def get_calendar_event!(id), do: Repo.get!(CalendarEvent, id)

  def create_calendar_event(attrs \\ %{}) do
    %CalendarEvent{}
    |> CalendarEvent.changeset(attrs)
    |> Repo.insert()
  end

  def update_calendar_event(%CalendarEvent{} = event, attrs) do
    event
    |> CalendarEvent.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_calendar_event(%CalendarEvent{} = event) do
    Repo.delete(event)
  end

  def change_calendar_event(%CalendarEvent{} = event, attrs \\ %{}) do
    CalendarEvent.changeset(event, attrs)
  end

  def create_attendee(attrs \\ %{}) do
    %CalendarEventAttendee{}
    |> CalendarEventAttendee.changeset(attrs)
    |> Repo.insert()
  end
end
