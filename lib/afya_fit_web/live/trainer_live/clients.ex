defmodule AfyaFitWeb.TrainerLive.Clients do
  @moduledoc """
  Clients: the list of people a trainer coaches, and the forms to add or edit one.
  """
  use AfyaFitWeb, :live_view

  import AfyaFitWeb.SignComponents

  alias AfyaFit.Accounts
  alias AfyaFit.Accounts.User
  alias AfyaFit.Authorization
  alias AfyaFit.Authorization.Entitlements
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
      |> assign(:form, nil)
      |> assign(:client, nil)
      |> assign(:status, nil)

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

  defp apply_action(socket, :index, params) do
    scope = socket.assigns.current_scope
    status = if params["status"] in @statuses, do: params["status"]
    filters = if status, do: %{status: status}, else: %{}
    clients = Clients.list_clients_for(scope, filters)

    socket
    |> assign(:status, status)
    |> assign(:client_count, scope.client_count)
    |> assign(:client_limit, Entitlements.client_limit(scope.tier))
    |> assign(:add_state, add_state(scope))
    |> maybe_open_limit(params)
    |> assign(:empty?, clients == [])
    |> stream(:clients, clients, reset: true)
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope

    case Authorization.authorize(scope, :create, :client) do
      :ok ->
        assign(socket, :form, to_form(User.registration_changeset(%User{}, %{}), as: "client"))

      error ->
        socket |> deny(error) |> push_navigate(to: ~p"/trainer/clients?limit=1")
    end
  end

  defp apply_action(socket, action, %{"id" => id}) when action in [:show, :edit] do
    with {:ok, client} <- fetch_client(socket, if(action == :show, do: :read, else: :update), id) do
      socket = assign(socket, :client, client)

      if action == :edit,
        do: assign(socket, :form, to_form(User.changeset(client, %{}), as: "client")),
        else:
          assign(
            socket,
            :can_upgrade?,
            Authorization.can?(socket.assigns.current_scope, :manage, :subscription)
          )
    else
      {:denied, denied} -> assign(socket, :denied, denied)
    end
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

  defp fetch_client(socket, action, id) do
    scope = socket.assigns.current_scope

    case Accounts.get_user(id) do
      %User{role: "client"} = client ->
        case Authorization.authorize(scope, action, client) do
          :ok -> {:ok, client}
          error -> {:denied, Access.denial(scope, error)}
        end

      _ ->
        {:denied, {:not_found, "That client is not here, or belongs to another organisation."}}
    end
  end

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

  defp deny(socket, error) do
    case Access.denial(socket.assigns.current_scope, error) do
      {:upgrade, details} -> assign(socket, :limit, details)
      {:read_only, _} -> put_flash(socket, :error, "Paused until payment clears.")
      {_kind, message} -> put_flash(socket, :error, message)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:clients}>
      <.denied_sign :if={@denied} kind={elem(@denied, 0)} message={elem(@denied, 1)} />

      <div :if={!@denied}>
        <.clients_index :if={@live_action == :index} {assigns} />
        <.clients_form :if={@live_action in [:new, :edit]} {assigns} />
        <.clients_show :if={@live_action == :show && @client} {assigns} />
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
        <b class="text-ink">{@client_count} of {limit_text(@client_limit)} places used.</b>
        {plan_sentence(@current_scope.tier)}
      </:subtitle>
    </.page_header>

    <.sign_group label="Your clients">
      <:actions>
        <.add_client_action state={@add_state} />
      </:actions>
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
          time={Calendar.strftime(client.inserted_at, "%-d %b")}
          time_label="Added"
        >
          <:title>{client.first_name} {client.last_name}</:title>
          {client.email}{if client.phone, do: " · #{client.phone}"}
          <:actions>
            <.sign_action navigate={~p"/trainer/clients/#{client.id}"}>Open</.sign_action>
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

  defp clients_form(assigns) do
    ~H"""
    <.page_header>
      {if @live_action == :new, do: "Add client", else: "Edit client"}
      <:subtitle>
        {if @live_action == :new,
          do: "We email an invitation when you save.",
          else: "#{@client.first_name} #{@client.last_name}"}
      </:subtitle>
    </.page_header>

    <.form
      for={@form}
      id="client-form"
      phx-submit={if @live_action == :new, do: "save", else: "update"}
      phx-change="validate"
      class="max-w-2xl px-4 py-6 sm:px-[26px]"
    >
      <div class="grid gap-x-6 sm:grid-cols-2">
        <.input field={@form[:first_name]} type="text" label="First name" required />
        <.input field={@form[:last_name]} type="text" label="Last name" required />
      </div>
      <.input field={@form[:email]} type="email" label="Email" required />
      <.input
        :if={@live_action == :new}
        field={@form[:password]}
        type="password"
        label="Password"
        required
      />
      <.input field={@form[:phone]} type="text" label="Phone" />

      <div class="mt-6 flex flex-wrap gap-3">
        <.button type="submit" variant="primary">
          {if @live_action == :new, do: "Create client", else: "Save"}
        </.button>
        <.button navigate={
          if @live_action == :new, do: ~p"/trainer/clients", else: ~p"/trainer/clients/#{@client.id}"
        }>
          Cancel
        </.button>
      </div>
    </.form>
    """
  end

  defp clients_show(assigns) do
    ~H"""
    <.page_header>
      {@client.first_name} {@client.last_name}
      <:subtitle>{@client.email}</:subtitle>
      <:actions>
        <.sign_action navigate={~p"/trainer/clients/#{@client.id}/edit"}>Edit</.sign_action>
      </:actions>
    </.page_header>

    <.sign_group label="Details">
      <div class="px-4 sm:px-[26px]">
        <.list>
          <:item title="Phone">{@client.phone || "Not provided"}</:item>
          <:item title="Time zone">{@client.timezone}</:item>
        </.list>
      </div>
    </.sign_group>

    <.sign_group label="Plans and progress">
      <.sign id="client-progress" icon={:progress} draw={false}>
        <:title>Progress</:title>
        Measurements and trends
        <:actions>
          <.sign_action navigate={~p"/trainer/progress/#{@client.id}"}>Open</.sign_action>
        </:actions>
      </.sign>
      <.sign id="client-workouts" icon={:workouts} draw={false}>
        <:title>Workouts</:title>
        Assign a plan from your library
        <:actions>
          <.sign_action navigate={~p"/trainer/workouts"}>Assign</.sign_action>
        </:actions>
      </.sign>
      <%= if Entitlements.allows?(@current_scope.tier, :nutrition_plans) do %>
        <.sign id="client-nutrition" icon={:nutrition} draw={false}>
          <:title>Nutrition</:title>
          Meal plans with calories and macros
          <:actions>
            <.sign_action navigate={~p"/trainer/nutrition"}>Open</.sign_action>
          </:actions>
        </.sign>
      <% else %>
        <.closed_sign
          id="client-nutrition"
          icon={:nutrition}
          title="Nutrition plans"
          can_upgrade={@can_upgrade?}
          owner_name={@current_scope.owner_name}
        >
          Meal plans with calories and macros.
        </.closed_sign>
      <% end %>
    </.sign_group>
    """
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

  def handle_event("validate", %{"client" => client_params}, socket) do
    changeset =
      case socket.assigns.live_action do
        :new -> User.registration_changeset(%User{}, client_params)
        :edit -> User.changeset(socket.assigns.client, client_params)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: "client"))}
  end

  def handle_event("save", %{"client" => client_params}, socket) do
    scope = socket.assigns.current_scope

    with :ok <- Authorization.authorize(scope, :create, :client),
         {:ok, _client} <- Clients.create_client(scope.user, client_params) do
      {:noreply,
       socket
       |> put_flash(:info, "Client added.")
       |> push_navigate(to: ~p"/trainer/clients")}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "client"))}

      error ->
        {:noreply, socket |> deny(error) |> push_patch(to: ~p"/trainer/clients")}
    end
  end

  def handle_event("update", %{"client" => client_params}, socket) do
    scope = socket.assigns.current_scope
    client = socket.assigns.client

    with :ok <- Authorization.authorize(scope, :update, client),
         {:ok, _client} <- Clients.update_client(client, client_params) do
      {:noreply,
       socket
       |> put_flash(:info, "Saved.")
       |> push_navigate(to: ~p"/trainer/clients/#{client.id}")}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "client"))}

      error ->
        {:noreply, deny(socket, error)}
    end
  end
end
