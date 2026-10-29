defmodule AfyaFit.Today do
  @moduledoc """
  What a trainer or organization admin opens the app to do today: the sessions
  on the day, and the clients who need them.

  Everything is limited to the clients the scope can reach, so a trainer sees
  their own clients and an organization admin sees the whole organization.
  Dates are UTC days; there is no time zone database yet, so event times are
  shown in UTC.
  """
  import Ecto.Query, warn: false

  alias AfyaFit.Accounts.User
  alias AfyaFit.Authorization
  alias AfyaFit.Authorization.{Entitlements, Scope}
  alias AfyaFit.Repo
  alias AfyaFit.Schedule
  alias AfyaFit.Tasks.Task
  alias AfyaFit.Tracking.ProgressEntry
  alias AfyaFit.Workouts.ClientWorkout

  @recent_days 3

  @type session :: %{
          kind: :event | :workout,
          id: binary(),
          client_id: binary() | nil,
          title: String.t(),
          detail: String.t() | nil,
          time: Time.t() | nil,
          state: :done | :next | :later
        }

  @type need :: %{
          kind: :tasks | :progress | :plan_end,
          client: User.t(),
          reason: String.t(),
          overdue: boolean()
        }

  @spec build(Scope.t(), DateTime.t()) :: %{
          sessions: [session()],
          needs_you: [need()],
          counts: %{done: non_neg_integer(), remaining: non_neg_integer()},
          client_count: non_neg_integer()
        }
  def build(%Scope{} = scope, now \\ DateTime.utc_now()) do
    today = DateTime.to_date(now)
    client_ids = reachable_client_ids(scope)
    clients = load_clients(client_ids)

    sessions =
      (events_today(scope, today) ++ workouts_today(clients, today))
      |> mark_states(now)

    %{
      sessions: sessions,
      needs_you: needs_you(clients, today, now),
      counts: %{
        done: Enum.count(sessions, &(&1.state == :done)),
        remaining: Enum.count(sessions, &(&1.state != :done))
      },
      client_count: map_size(clients)
    }
  end

  defp reachable_client_ids(%Scope{} = scope) do
    scope |> Authorization.visible(:client) |> select([u], u.id) |> Repo.all()
  end

  defp load_clients([]), do: %{}

  defp load_clients(ids),
    do: Repo.all(from u in User, where: u.id in ^ids) |> Map.new(&{&1.id, &1})

  ## Sessions

  # Calendar events are a Pro feature; on Free the day is built from workouts.
  defp events_today(scope, today) do
    if Entitlements.allows?(scope.tier, :calendar) do
      scope.user.id
      |> Schedule.list_calendar_events()
      |> Enum.filter(&(DateTime.to_date(&1.start_time) == today))
      |> Enum.map(fn event ->
        %{
          kind: :event,
          id: event.id,
          client_id: nil,
          title: event.title,
          detail: event.description,
          time: DateTime.to_time(event.start_time),
          starts_at: event.start_time,
          state: :later
        }
      end)
      |> Enum.sort_by(& &1.time, Time)
    else
      []
    end
  end

  defp workouts_today(clients, _today) when map_size(clients) == 0, do: []

  defp workouts_today(clients, today) do
    ids = Map.keys(clients)

    Repo.all(
      from cw in ClientWorkout,
        join: wp in assoc(cw, :workout_plan),
        where: cw.client_id in ^ids and cw.start_date == ^today,
        order_by: [asc: cw.inserted_at],
        select: {cw, wp.name}
    )
    |> Enum.map(fn {cw, plan_name} ->
      %{
        kind: :workout,
        id: cw.id,
        client_id: cw.client_id,
        title: full_name(clients[cw.client_id]),
        detail: plan_name,
        time: nil,
        starts_at: nil,
        state: if(cw.status == "completed", do: :done, else: :later)
      }
    end)
  end

  # Events in the past are done; the first open session is next, the rest later.
  defp mark_states(sessions, now) do
    sessions =
      Enum.map(sessions, fn
        %{kind: :event, starts_at: starts_at} = session ->
          if DateTime.compare(starts_at, now) == :lt, do: %{session | state: :done}, else: session

        session ->
          session
      end)

    {marked, _next_taken?} =
      Enum.map_reduce(sessions, false, fn
        %{state: :done} = session, taken -> {session, taken}
        session, false -> {%{session | state: :next}, true}
        session, true -> {%{session | state: :later}, true}
      end)

    Enum.map(marked, &Map.delete(&1, :starts_at))
  end

  ## Needs you

  defp needs_you(clients, _today, _now) when map_size(clients) == 0, do: []

  defp needs_you(clients, today, now) do
    ids = Map.keys(clients)

    (overdue_tasks(clients, ids, now) ++
       recent_progress(clients, ids, today) ++ plans_ending(clients, ids, today))
    |> Enum.sort_by(&if(&1.overdue, do: 0, else: 1))
  end

  defp overdue_tasks(clients, ids, now) do
    Repo.all(
      from t in Task,
        where:
          t.client_id in ^ids and t.status in ["pending", "in_progress"] and t.due_date < ^now,
        group_by: t.client_id,
        select: {t.client_id, count(t.id)}
    )
    |> Enum.map(fn {client_id, count} ->
      %{
        kind: :tasks,
        client: clients[client_id],
        reason: "#{count} #{if count == 1, do: "task", else: "tasks"} overdue",
        overdue: true
      }
    end)
  end

  defp recent_progress(clients, ids, today) do
    since = Date.add(today, -@recent_days)

    Repo.all(
      from p in ProgressEntry,
        where: p.client_id in ^ids,
        order_by: [desc: p.entry_date]
    )
    |> Enum.group_by(& &1.client_id)
    |> Enum.flat_map(fn {client_id, [latest | rest]} ->
      if Date.compare(latest.entry_date, since) != :lt and latest.weight do
        [
          %{
            kind: :progress,
            client: clients[client_id],
            reason: progress_reason(latest, List.first(rest)),
            overdue: false
          }
        ]
      else
        []
      end
    end)
  end

  defp progress_reason(latest, nil), do: "Logged #{kg(latest.weight)}"

  defp progress_reason(latest, previous) do
    change = Decimal.sub(latest.weight, previous.weight)
    since = Calendar.strftime(previous.entry_date, "%-d %b")

    direction =
      case Decimal.compare(change, 0) do
        :lt -> "down #{kg_value(Decimal.abs(change))}"
        :gt -> "up #{kg_value(change)}"
        :eq -> "unchanged"
      end

    "Logged #{kg(latest.weight)}, #{direction} since #{since}"
  end

  defp kg(weight), do: "#{kg_value(weight)} kg"
  defp kg_value(weight), do: weight |> Decimal.round(1) |> Decimal.to_string(:normal)

  defp plans_ending(clients, ids, today) do
    until = Date.add(today, @recent_days)

    Repo.all(
      from cw in ClientWorkout,
        join: wp in assoc(cw, :workout_plan),
        where:
          cw.client_id in ^ids and cw.status != "completed" and cw.end_date >= ^today and
            cw.end_date <= ^until,
        select: {cw.client_id, wp.name, cw.end_date}
    )
    |> Enum.map(fn {client_id, plan_name, end_date} ->
      %{
        kind: :plan_end,
        client: clients[client_id],
        reason: "#{plan_name} ends #{Calendar.strftime(end_date, "%a %-d %b")}",
        overdue: false
      }
    end)
  end

  defp full_name(%User{first_name: first, last_name: last}), do: String.trim("#{first} #{last}")
end
