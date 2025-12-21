defmodule AfyaFitWeb.API.JSON.CalendarEventJSON do
  @moduledoc """
  JSON serialization for CalendarEvent resources.
  """

  def index(%{calendar_events: calendar_events}) do
    %{data: for(event <- calendar_events, do: data(event))}
  end

  def show(%{calendar_event: calendar_event}) do
    %{data: data(calendar_event)}
  end

  defp data(%{id: id} = event) do
    %{
      id: id,
      title: event.title,
      description: event.description,
      event_type: event.event_type,
      start_time: event.start_time,
      end_time: event.end_time,
      is_all_day: event.is_all_day,
      timezone: event.timezone,
      location: event.location,
      related_id: event.related_id,
      related_type: event.related_type,
      organization_id: event.organization_id,
      user_id: event.user_id,
      inserted_at: event.inserted_at,
      updated_at: event.updated_at
    }
  end
end
