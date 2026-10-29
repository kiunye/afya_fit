defmodule AfyaFitWeb.TrainerLive.Progress do
  @moduledoc """
  Progress: measurements over time for each client. Analytics are a Pro
  feature and show as a closed sign on Free.
  """
  use AfyaFitWeb, :live_view

  import AfyaFitWeb.SignComponents

  alias AfyaFit.{Authorization, Clients, Tracking}
  alias AfyaFitWeb.Access

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> Access.guard(:list, :progress_entry)
      |> assign(:page_title, "Progress")
      |> assign(:client, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    if socket.assigns.denied do
      {:noreply, socket}
    else
      {:noreply, apply_action(socket, socket.assigns.live_action, params)}
    end
  end

  defp apply_action(socket, :index, _params) do
    clients = Clients.list_clients_for(socket.assigns.current_scope)

    socket
    |> assign(:count, length(clients))
    |> assign(:empty?, clients == [])
    |> stream(:clients, clients, reset: true)
  end

  defp apply_action(socket, :client, %{"client_id" => client_id}) do
    scope = socket.assigns.current_scope

    case Clients.fetch_for(scope, :read, client_id) do
      {:ok, client} ->
        entries = Tracking.list_progress_entries(client.id)

        socket
        |> assign(:client, client)
        |> assign(:analytics?, Authorization.can?(scope, :analytics, :progress_entry))
        |> assign(:can_upgrade?, Authorization.can?(scope, :manage, :subscription))
        |> assign(:analytics, calculate_analytics(entries))
        |> assign(:empty?, entries == [])
        |> stream(:entries, Enum.sort_by(entries, & &1.entry_date, {:desc, Date}), reset: true)

      error ->
        assign(socket, :denied, Access.denial(scope, error))
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:progress}>
      <.denied_sign :if={@denied} kind={elem(@denied, 0)} message={elem(@denied, 1)} />
      <div :if={!@denied}>
        <.progress_index :if={@live_action == :index} {assigns} />
        <.progress_client :if={@live_action == :client && @client} {assigns} />
      </div>
    </Layouts.app>
    """
  end

  defp progress_index(assigns) do
    ~H"""
    <.page_header>
      Progress
      <:subtitle>
        <b class="text-ink">{@count} {if @count == 1, do: "client", else: "clients"}.</b>
        Pick one to see their measurements.
      </:subtitle>
    </.page_header>

    <.sign_group label="Clients">
      <div id="clients" phx-update="stream">
        <div
          id="clients-empty"
          class="hidden border-b border-line/40 px-4 py-6 text-ink-2 only:block sm:px-[26px]"
        >
          No clients yet. Add a client to start tracking their progress.
        </div>
        
        <.sign :for={{id, client} <- @streams.clients} id={id} icon={:progress}>
          <:title>{client.first_name} {client.last_name}</:title>
           {client.email}
          <:actions>
            <.sign_action navigate={~p"/trainer/progress/#{client.id}"}>Open</.sign_action>
          </:actions>
        </.sign>
      </div>
    </.sign_group>
    """
  end

  defp progress_client(assigns) do
    ~H"""
    <.page_header>
      {@client.first_name} {@client.last_name}
      <:subtitle>
        <b class="text-ink">
          {@analytics.total_entries} {if @analytics.total_entries == 1, do: "entry", else: "entries"}.
        </b> {@client.email}
      </:subtitle>
      
      <:actions>
        <.sign_action navigate={~p"/trainer/clients/#{@client.id}"}>Client</.sign_action>
      </:actions>
    </.page_header>

    <.sign_group label="Analytics">
      <.closed_sign
        :if={!@analytics?}
        id="analytics-closed"
        icon={:progress}
        title="Analytics"
        can_upgrade={@can_upgrade?}
        owner_name={@current_scope.owner_name}
      >
        Weight and body-fat change over time. Your entries stay readable.
      </.closed_sign>
      
      <div :if={@analytics?} id="analytics">
        <.sign
          id="weight-change"
          icon={:progress}
          draw={false}
          time={change_text(@analytics.weight_change, "kg")}
          time_label="Weight"
        >
          <:title>Weight change</:title>
          First entry to latest
        </.sign>
        
        <.sign
          id="body-fat-change"
          icon={:progress}
          draw={false}
          time={change_text(@analytics.body_fat_change, "%")}
          time_label="Body fat"
        >
          <:title>Body-fat change</:title>
          First entry to latest
        </.sign>
      </div>
    </.sign_group>

    <.sign_group label="Entries">
      <div id="entries" phx-update="stream">
        <div
          id="entries-empty"
          class="hidden border-b border-line/40 px-4 py-6 text-ink-2 only:block sm:px-[26px]"
        >
          No entries yet. Measurements appear here as they are logged.
        </div>
        
        <.sign
          :for={{id, entry} <- @streams.entries}
          id={id}
          icon={:progress}
          draw={false}
          time={Calendar.strftime(entry.entry_date, "%-d %b")}
          time_label={Calendar.strftime(entry.entry_date, "%Y")}
        >
          <:title>{weight_text(entry)}</:title>
           {entry_detail(entry)}
        </.sign>
      </div>
    </.sign_group>
    """
  end

  defp weight_text(%{weight: nil}), do: "No weight"
  defp weight_text(%{weight: weight}), do: "#{format_decimal(weight)} kg"

  defp entry_detail(entry) do
    [
      entry.body_fat_percentage && "#{format_decimal(entry.body_fat_percentage)}% body fat",
      entry.notes
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" · ")
  end

  defp change_text(nil, _unit), do: "—"

  defp change_text(%Decimal{} = change, unit) do
    sign = if Decimal.compare(change, 0) == :gt, do: "+", else: ""
    "#{sign}#{format_decimal(change)} #{unit}"
  end

  defp calculate_analytics(entries) do
    sorted = Enum.sort_by(entries, & &1.entry_date, {:asc, Date})

    %{
      total_entries: length(entries),
      weight_change: change(sorted, :weight),
      body_fat_change: change(sorted, :body_fat_percentage)
    }
  end

  defp change([], _field), do: nil

  defp change([first | _] = sorted, field) do
    last = List.last(sorted)
    a = Map.fetch!(first, field)
    b = Map.fetch!(last, field)
    if a && b, do: Decimal.sub(b, a), else: nil
  end

  defp format_decimal(%Decimal{} = decimal),
    do: decimal |> Decimal.round(1) |> Decimal.to_string(:normal)

  defp format_decimal(value) when is_number(value),
    do: :erlang.float_to_binary(value / 1, decimals: 1)

  defp format_decimal(_value), do: "—"
end
