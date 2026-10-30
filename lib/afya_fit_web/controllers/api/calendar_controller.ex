defmodule AfyaFitWeb.API.CalendarController do
  use AfyaFitWeb, :controller

  alias AfyaFit.{Authorization, Schedule}

  # Authentication is handled in router pipeline

  action_fallback AfyaFitWeb.API.FallbackController

  def index(conn, params) do
    scope = conn.assigns.current_scope
    start_date = parse_date(params["start_date"])
    end_date = parse_date(params["end_date"])

    with :ok <- Authorization.authorize(scope, :list, :calendar_event) do
      events =
        scope
        |> own_events()
        |> Enum.filter(fn event ->
          (is_nil(start_date) or DateTime.compare(event.start_time, start_date) != :lt) and
            (is_nil(start_date) or is_nil(end_date) or
               DateTime.compare(event.start_time, end_date) != :gt)
        end)

      render(conn, :index, calendar_events: events)
    end
  end

  def create(conn, %{"calendar_event" => event_params}) do
    scope = conn.assigns.current_scope

    zone = AfyaFit.Timezone.zone(scope)

    attrs =
      event_params
      |> localize_times(zone)
      |> Map.put_new("timezone", zone)
      |> Map.put("organization_id", scope.user.organization_id)
      |> Map.put("user_id", scope.user.id)

    with :ok <- Authorization.authorize(scope, :create, :calendar_event),
         {:ok, calendar_event} <- Schedule.create_calendar_event(attrs) do
      conn
      |> put_status(:created)
      |> render(:show, calendar_event: calendar_event)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, calendar_event} <- fetch_event(conn, :read, id) do
      render(conn, :show, calendar_event: calendar_event)
    end
  end

  def update(conn, %{"id" => id, "calendar_event" => event_params}) do
    with {:ok, calendar_event} <- fetch_event(conn, :update, id),
         {:ok, calendar_event} <-
           Schedule.update_calendar_event(
             calendar_event,
             localize_times(event_params, AfyaFit.Timezone.zone(conn.assigns.current_scope))
           ) do
      render(conn, :show, calendar_event: calendar_event)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, calendar_event} <- fetch_event(conn, :delete, id),
         {:ok, _calendar_event} <- Schedule.delete_calendar_event(calendar_event) do
      send_resp(conn, :no_content, "")
    end
  end

  def upcoming(conn, params) do
    scope = conn.assigns.current_scope
    days = String.to_integer(params["days"] || "7")

    now = DateTime.utc_now()
    cutoff_date = DateTime.add(now, days, :day)

    with :ok <- Authorization.authorize(scope, :list, :calendar_event) do
      events =
        scope
        |> own_events()
        |> Enum.filter(fn event ->
          DateTime.compare(event.start_time, now) != :lt &&
            DateTime.compare(event.start_time, cutoff_date) != :gt
        end)
        |> Enum.sort_by(& &1.start_time, {:asc, DateTime})

      render(conn, :index, calendar_events: events)
    end
  end

  # A time with an offset is an exact instant; one without is the user's wall-clock time.
  defp localize_times(params, zone) do
    Enum.reduce(["start_time", "end_time"], params, fn key, acc ->
      with value when is_binary(value) <- acc[key],
           {:ok, utc} <- AfyaFit.Timezone.parse(value, zone) do
        Map.put(acc, key, DateTime.to_iso8601(utc))
      else
        _ -> acc
      end
    end)
  end

  defp own_events(scope) do
    scope.user.id
    |> Schedule.list_calendar_events()
    |> Enum.filter(&(&1.organization_id == scope.user.organization_id))
  end

  defp fetch_event(conn, action, id) do
    calendar_event = Schedule.get_calendar_event!(id)

    with :ok <- Authorization.authorize(conn.assigns.current_scope, action, calendar_event) do
      {:ok, calendar_event}
    end
  end

  defp parse_date(nil), do: nil

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      {:error, _} -> nil
    end
  end

  defp parse_date(_), do: nil
end
