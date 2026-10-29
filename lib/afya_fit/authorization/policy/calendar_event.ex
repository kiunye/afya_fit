defmodule AfyaFit.Authorization.Policy.CalendarEvent do
  @moduledoc """
  Events belong to their creator. Clients can see the events they attend, which
  requires `calendar_event_attendees` to be preloaded.
  """
  @behaviour AfyaFit.Authorization.Policy

  alias AfyaFit.Authorization.Policy
  alias AfyaFit.Authorization.Scope

  @impl true
  def check(scope, _action, event) do
    Policy.allow?(Scope.self?(scope, event.user_id) or attendee?(scope, event))
  end

  defp attendee?(scope, %{calendar_event_attendees: attendees}) when is_list(attendees) do
    Enum.any?(attendees, &Scope.self?(scope, &1.user_id))
  end

  defp attendee?(_scope, _event), do: false
end
