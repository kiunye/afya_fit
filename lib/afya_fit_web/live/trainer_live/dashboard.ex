defmodule AfyaFitWeb.TrainerLive.Dashboard do
  @moduledoc """
  Today: the sessions on the day and the clients who need the trainer.
  """
  use AfyaFitWeb, :live_view

  import AfyaFitWeb.SignComponents

  alias AfyaFit.Authorization
  alias AfyaFit.Authorization.Entitlements
  alias AfyaFit.Today
  alias AfyaFitWeb.Access

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    socket =
      socket
      |> Access.guard(:create, :client)
      |> assign(:page_title, "Today")

    if socket.assigns.denied do
      {:ok, socket}
    else
      today = Today.build(scope)

      {:ok,
       socket
       |> assign(:counts, today.counts)
       |> assign(:client_count, today.client_count)
       |> assign(:calendar?, Entitlements.allows?(scope.tier, :calendar))
       |> assign(:can_upgrade?, Authorization.can?(scope, :manage, :subscription))
       |> assign(:sessions_empty?, today.sessions == [])
       |> assign(:needs_empty?, today.needs_you == [])
       |> assign(:needs_count, length(today.needs_you))
       |> stream(:sessions, today.sessions)
       |> stream(:needs, Enum.map(today.needs_you, &need_row/1))}
    end
  end

  defp need_row(need), do: Map.put(need, :id, "need-#{need.kind}-#{need.client.id}")

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:today}>
      <.denied_sign :if={@denied} kind={elem(@denied, 0)} message={elem(@denied, 1)} />
      <div :if={!@denied} id="today">
        <.page_header>
          Today · {Calendar.strftime(Date.utc_today(), "%a %-d %b")}
          <:subtitle>
            <b class="text-ink">{@counts.done} done, {@counts.remaining} to go.</b> {needs_sentence(
              @needs_count,
              @client_count
            )}
          </:subtitle>
        </.page_header>
        
        <.sign_group label="Sessions">
          <div id="sessions" phx-update="stream">
            <div
              id="sessions-empty"
              class="hidden border-b border-line/40 px-4 py-6 text-ink-2 only:block sm:px-[26px]"
            >
              Nothing scheduled today. Assign a workout to see it here.
              <.link navigate={~p"/trainer/workouts"} class="font-bold text-ink underline">
                Open workouts
              </.link>
            </div>
            
            <.sign
              :for={{id, session} <- @streams.sessions}
              id={id}
              icon={session_icon(session)}
              state={session.state}
              time={session_time(session)}
              time_label={state_label(session.state)}
            >
              <:title>{session.title}</:title>
               {session.detail}
              <:actions :if={session.client_id}>
                <.sign_action navigate={~p"/trainer/clients/#{session.client_id}"}>Open</.sign_action>
              </:actions>
            </.sign>
          </div>
          
          <.closed_sign
            :if={!@calendar?}
            id="calendar-closed"
            icon={:today}
            title="Calendar"
            can_upgrade={@can_upgrade?}
            owner_name={@current_scope.owner_name}
          >
            Book sessions and see them here.
          </.closed_sign>
        </.sign_group>
        
        <.sign_group label="Needs you">
          <div id="needs" phx-update="stream">
            <div
              id="needs-empty"
              class="hidden border-b border-line/40 px-4 py-6 text-ink-2 only:block sm:px-[26px]"
            >
              Nobody needs you right now.
            </div>
            
            <.sign
              :for={{id, need} <- @streams.needs}
              id={id}
              icon={need_icon(need)}
              state={if need.overdue, do: :next, else: :later}
              overdue={need.overdue}
            >
              <:title>{need.client.first_name} {need.client.last_name}</:title>
               {need.reason}
              <:actions>
                <.sign_action
                  primary={need.overdue}
                  navigate={need_path(need)}
                >
                  {need_action(need)}
                </.sign_action>
              </:actions>
            </.sign>
          </div>
        </.sign_group>
      </div>
    </Layouts.app>
    """
  end

  defp needs_sentence(0, 0), do: "Add your first client to get started."

  defp needs_sentence(0, clients),
    do: "#{clients} #{pluralize(clients, "client")}, nobody waiting on you."

  defp needs_sentence(n, _clients),
    do: "#{n} #{pluralize(n, "client")} #{if n == 1, do: "needs", else: "need"} you."

  defp pluralize(1, word), do: word
  defp pluralize(_n, word), do: word <> "s"

  defp session_icon(%{kind: :event}), do: :today
  defp session_icon(%{kind: :workout}), do: :workouts

  defp session_time(%{time: %Time{} = time}), do: Calendar.strftime(time, "%H:%M")
  defp session_time(_session), do: nil

  defp state_label(:done), do: "Done"
  defp state_label(:next), do: "Next"
  defp state_label(:later), do: "Later"

  defp need_icon(%{kind: :tasks}), do: :alert
  defp need_icon(%{kind: :progress}), do: :progress
  defp need_icon(%{kind: :plan_end}), do: :workouts

  defp need_path(%{kind: :progress, client: client}), do: ~p"/trainer/progress/#{client.id}"
  defp need_path(%{client: client}), do: ~p"/trainer/clients/#{client.id}"

  defp need_action(%{kind: :tasks}), do: "Open client"
  defp need_action(%{kind: :progress}), do: "See progress"
  defp need_action(%{kind: :plan_end}), do: "Assign next"
end
