defmodule AfyaFitWeb.TrainerLive.Clients do
  @moduledoc """
  Clients: the list of people a trainer coaches, with filters, archiving and
  restoring, and the plan limit. Adding, editing and viewing one are
  `TrainerLive.ClientForm` and `TrainerLive.ClientShow`.
  """
  use AfyaFitWeb, :live_view

  import AfyaFitWeb.SignComponents

  alias AfyaFit.Accounts.User
  alias AfyaFit.Authorization
  alias AfyaFit.Authorization.Entitlements
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Clients
  alias AfyaFitWeb.Access

  @statuses ~w(active paused archived)

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> Access.guard(:list, :client)
      |> assign(:page_title, "Clients")
      |> assign(:limit, nil)
      |> assign(:status, nil)
      |> assign(:confirm_archive, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, %{assigns: %{denied: denied}} = socket) when denied != nil,
    do: {:noreply, socket}

  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope
    status = if params["status"] in @statuses, do: params["status"]
    filters = if status, do: %{status: status}, else: %{}
    clients = Clients.list_clients_for(scope, filters)

    {:noreply,
     socket
     |> assign(:status, status)
     |> assign(:client_count, scope.client_count)
     |> assign(:client_limit, Entitlements.client_limit(scope.tier))
     |> assign(:add_state, add_state(scope))
     |> assign(:can_archive?, Authorization.can?(scope, :delete, :client))
     |> assign(:confirm_archive, nil)
     |> maybe_open_limit(params)
     |> assign(:empty?, clients == [])
     |> stream(:clients, clients, reset: true)}
  end

  # `?limit=1` reopens the limit dialog after a redirect from a blocked action.
  defp maybe_open_limit(socket, %{"limit" => "1"}) do
    scope = socket.assigns.current_scope

    if socket.assigns.add_state == :limit,
      do:
        assign(socket, :limit, %{can_upgrade: Authorization.can?(scope, :manage, :subscription)}),
      else: socket
  end

  defp maybe_open_limit(socket, _params), do: socket

  # What the "Add client" action does right now: :ok, :limit (opens the dialog)
  # or :paused (read-only account, stays visible but unavailable).
  defp add_state(scope) do
    case Authorization.authorize(scope, :create, :client) do
      :ok -> :ok
      {:error, {:upgrade_required, _}} -> :limit
      {:error, {:subscription_inactive, _}} -> :paused
      {:error, _} -> :hidden
    end
  end

  # A plan limit opens the dialog; every other denial is a flash.
  defp deny(socket, error) do
    case Access.denial(socket.assigns.current_scope, error) do
      {:upgrade, details} ->
        Access.record_block(socket.assigns.current_scope, error)
        assign(socket, :limit, details)

      _other ->
        Access.flash_denial(socket, error)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:clients}>
      <.denied_sign :if={@denied} kind={elem(@denied, 0)} message={elem(@denied, 1)} />
      <div :if={!@denied}>
        <.clients_index {assigns} />
      </div>

      <.limit_dialog
        :if={@limit}
        id="limit-dialog"
        title="Client limit reached"
        current_label="Free, now"
        current_value={"#{Entitlements.client_limit(@current_scope.tier)} clients"}
        upgraded_value={"#{Entitlements.client_limit("pro")} clients"}
        can_upgrade={@limit.can_upgrade}
        owner_name={@current_scope.owner_name}
        on_cancel={JS.push("close_limit")}
      >
        {@current_scope.organization && @current_scope.organization.name} is on Free, which has
        room for {Entitlements.client_limit(@current_scope.tier)} clients. Add another by moving to Pro.
      </.limit_dialog>
    </Layouts.app>
    """
  end

  defp clients_index(assigns) do
    ~H"""
    <.page_header>
      Clients
      <:subtitle>
        <b class="text-ink">{@client_count} of {limit_text(@client_limit)} places used.</b> {plan_sentence(
          @current_scope.tier
        )}
      </:subtitle>
    </.page_header>

    <.sign_group label="Your clients">
      <:actions><.add_client_action state={@add_state} /></:actions>

      <nav aria-label="Filter" class="flex gap-2 px-4 pb-3 sm:px-[26px]">
        <.link
          :for={
            {label, value} <- [
              {"All", nil},
              {"Active", "active"},
              {"Paused", "paused"},
              {"Archived", "archived"}
            ]
          }
          patch={if value, do: ~p"/trainer/clients?status=#{value}", else: ~p"/trainer/clients"}
          aria-current={@status == value && "true"}
          class={[
            "rounded-control border-2 px-3 py-1 text-xs font-bold uppercase tracking-[.06em]",
            @status == value && "border-white bg-white text-field-0",
            @status != value && "border-line/50 text-ink-2 hover:border-white hover:text-white"
          ]}
        >
          {label}
        </.link>
      </nav>

      <.sign
        :if={@confirm_archive}
        id="archive-confirm"
        icon={:alert}
        state={:next}
        draw={false}
      >
        <:title>Archive {@confirm_archive.first_name} {@confirm_archive.last_name}?</:title>
        They stop appearing in your list and free a place on your plan. Their plans and progress
        are kept and they can still sign in, but only to view them. You can restore them later.
        <:actions>
          <.sign_action id="confirm-archive" primary phx-click="archive">Archive client</.sign_action>

          <.sign_action id="keep-client" phx-click="cancel_archive">Keep</.sign_action>
        </:actions>
      </.sign>

      <div id="clients" phx-update="stream">
        <div
          id="clients-empty"
          class="hidden border-b border-line/40 px-4 py-6 text-ink-2 only:block sm:px-[26px]"
        >
          <%= if @status do %>
            No {@status} clients.
            <.link patch={~p"/trainer/clients"} class="font-bold text-ink underline">Show all</.link>
          <% else %>
            Add your first client. They get a workout plan, a nutrition plan and a place to log progress.
          <% end %>
        </div>

        <.sign
          :for={{id, client} <- @streams.clients}
          id={id}
          icon={:clients}
          time={local(client.inserted_at, @current_scope, "%-d %b")}
          time_label="Added"
        >
          <:title>{client.first_name} {client.last_name}</:title>
          {client.email}{if client.phone, do: " · #{client.phone}"}
          <:actions>
            <.sign_action :if={@status != "archived"} navigate={~p"/trainer/clients/#{client.id}"}>
              Open
            </.sign_action>

            <.sign_action
              :if={@can_archive? && @status != "archived"}
              id={"archive-#{client.id}"}
              phx-click="ask_archive"
              phx-value-id={client.id}
            >
              Archive
            </.sign_action>

            <.sign_action
              :if={@status == "archived"}
              id={"restore-#{client.id}"}
              phx-click="restore"
              phx-value-id={client.id}
            >
              Restore
            </.sign_action>
          </:actions>
        </.sign>
      </div>
    </.sign_group>
    """
  end

  attr :state, :atom, required: true

  defp add_client_action(assigns) do
    ~H"""
    <.sign_action :if={@state == :ok} id="add-client" primary navigate={~p"/trainer/clients/new"}>
      Add client
    </.sign_action>

    <.sign_action :if={@state == :limit} id="add-client" primary phx-click="add_client">
      Add client
    </.sign_action>

    <span :if={@state == :paused} class="flex items-center gap-3 text-sm text-ink-2">
      Paused until payment clears
      <.sign_action id="add-client" aria-disabled="true">Add client</.sign_action>
    </span>
    """
  end

  # The plan count and the list both change, so reload the scope and the page.
  defp refresh(socket, message) do
    scope = Scope.load(socket.assigns.current_scope.user)
    status = socket.assigns.status
    path = if status, do: ~p"/trainer/clients?status=#{status}", else: ~p"/trainer/clients"

    socket
    |> assign(:current_scope, scope)
    |> put_flash(:info, message)
    |> push_patch(to: path)
  end

  defp limit_text(:infinity), do: "unlimited"
  defp limit_text(n), do: to_string(n)

  defp plan_sentence("free"), do: "Pro has 25."
  defp plan_sentence("pro"), do: "Enterprise has no limit."
  defp plan_sentence(_tier), do: ""

  @impl true
  def handle_event("add_client", _params, socket) do
    case Authorization.authorize(socket.assigns.current_scope, :create, :client) do
      :ok -> {:noreply, push_navigate(socket, to: ~p"/trainer/clients/new")}
      error -> {:noreply, deny(socket, error)}
    end
  end

  def handle_event("close_limit", _params, socket), do: {:noreply, assign(socket, :limit, nil)}

  def handle_event("ask_archive", %{"id" => id}, socket) do
    case Clients.fetch_for(socket.assigns.current_scope, :delete, id) do
      {:ok, client} -> {:noreply, assign(socket, :confirm_archive, client)}
      error -> {:noreply, deny(socket, error)}
    end
  end

  def handle_event("cancel_archive", _params, socket),
    do: {:noreply, assign(socket, :confirm_archive, nil)}

  def handle_event("archive", _params, %{assigns: %{confirm_archive: %User{} = client}} = socket) do
    scope = socket.assigns.current_scope

    with :ok <- Authorization.authorize(scope, :delete, client),
         {:ok, _links} <- Clients.archive_client_links(client, scope) do
      {:noreply, refresh(socket, "#{client.first_name} archived.")}
    else
      error -> {:noreply, socket |> assign(:confirm_archive, nil) |> deny(error)}
    end
  end

  def handle_event("archive", _params, socket), do: {:noreply, socket}

  def handle_event("restore", %{"id" => id}, socket) do
    case Clients.restore_client(socket.assigns.current_scope, id) do
      {:ok, _link} -> {:noreply, refresh(socket, "Client restored.")}
      error -> {:noreply, deny(socket, error)}
    end
  end
end
