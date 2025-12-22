defmodule AfyaFitWeb.API.CalendarController do
  use AfyaFitWeb, :controller

  alias AfyaFit.Schedule

  # Authentication is handled in router pipeline

  action_fallback AfyaFitWeb.API.FallbackController

  def index(conn, params) do
    current_user = conn.assigns.current_user

    # Get date range filters
    start_date = parse_date(params["start_date"])
    end_date = parse_date(params["end_date"])

    events = Schedule.list_calendar_events(current_user.id)

    events =
      cond do
        start_date && end_date ->
          Enum.filter(events, fn event ->
            DateTime.compare(event.start_time, start_date) != :lt &&
              DateTime.compare(event.start_time, end_date) != :gt
          end)

        start_date ->
          Enum.filter(events, fn event ->
            DateTime.compare(event.start_time, start_date) != :lt
          end)

        true ->
          events
      end

    # Filter by organization
    events =
      Enum.filter(events, fn event ->
        event.organization_id == current_user.organization_id
      end)

    render(conn, :index, calendar_events: events)
  end

  def create(conn, %{"calendar_event" => event_params}) do
    current_user = conn.assigns.current_user

    attrs =
      event_params
      |> Map.put("organization_id", current_user.organization_id)
      |> Map.put("user_id", current_user.id)

    case Schedule.create_calendar_event(attrs) do
      {:ok, calendar_event} ->
        conn
        |> put_status(:created)
        |> render(:show, calendar_event: calendar_event)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"422", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    calendar_event = Schedule.get_calendar_event!(id)

    # Verify access
    if calendar_event.organization_id == current_user.organization_id &&
         (calendar_event.user_id == current_user.id || current_user.role in ["admin", "trainer"]) do
      render(conn, :show, calendar_event: calendar_event)
    else
      conn
      |> put_status(:forbidden)
      |> put_view(AfyaFitWeb.API.ErrorView)
      |> render(:"403")
    end
  end

  def update(conn, %{"id" => id, "calendar_event" => event_params}) do
    current_user = conn.assigns.current_user
    calendar_event = Schedule.get_calendar_event!(id)

    # Verify ownership
    if calendar_event.user_id == current_user.id || current_user.role == "admin" do
      case Schedule.update_calendar_event(calendar_event, event_params) do
        {:ok, calendar_event} ->
          render(conn, :show, calendar_event: calendar_event)

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(AfyaFitWeb.API.ErrorView)
          |> render(:"422", changeset: changeset)
      end
    else
      conn
      |> put_status(:forbidden)
      |> put_view(AfyaFitWeb.API.ErrorView)
      |> render(:"403")
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    calendar_event = Schedule.get_calendar_event!(id)

    # Verify ownership
    if calendar_event.user_id == current_user.id || current_user.role == "admin" do
      Schedule.delete_calendar_event(calendar_event)
      send_resp(conn, :no_content, "")
    else
      conn
      |> put_status(:forbidden)
      |> put_view(AfyaFitWeb.API.ErrorView)
      |> render(:"403")
    end
  end

  def upcoming(conn, params) do
    current_user = conn.assigns.current_user
    days = String.to_integer(params["days"] || "7")

    now = DateTime.utc_now()
    cutoff_date = DateTime.add(now, days, :day)

    events =
      Schedule.list_calendar_events(current_user.id)
      |> Enum.filter(fn event ->
        event.organization_id == current_user.organization_id &&
          DateTime.compare(event.start_time, now) != :lt &&
          DateTime.compare(event.start_time, cutoff_date) != :gt
      end)
      |> Enum.sort_by(& &1.start_time, {:asc, DateTime})

    render(conn, :index, calendar_events: events)
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
