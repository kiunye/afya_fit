defmodule AfyaFitWeb.TrainerLive.ClientForm do
  @moduledoc """
  The form to add a client, or to edit one's details.
  """
  use AfyaFitWeb, :live_view

  import AfyaFitWeb.SignComponents

  alias AfyaFit.Accounts.User
  alias AfyaFit.Authorization
  alias AfyaFit.Clients
  alias AfyaFitWeb.Access

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> Access.guard(:list, :client)
      |> assign(:page_title, "Clients")
      |> assign(:form, nil)
      |> assign(:client, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, %{assigns: %{denied: denied}} = socket) when denied != nil,
    do: {:noreply, socket}

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope

    case Authorization.authorize(scope, :create, :client) do
      :ok ->
        assign(socket, :form, to_form(User.registration_changeset(%User{}, %{}), as: "client"))

      error ->
        refuse(socket, error)
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope

    case Clients.fetch_for(scope, :update, id) do
      {:ok, client} ->
        socket
        |> assign(:client, client)
        |> assign(:form, to_form(User.profile_changeset(client, %{}), as: "client"))

      error ->
        assign(socket, :denied, Access.denial(scope, error))
    end
  end

  # The plan limit is explained on the list, which opens its dialog; every other
  # refusal is a flash there.
  defp refuse(socket, error) do
    scope = socket.assigns.current_scope

    case Access.denial(scope, error) do
      {:upgrade, _details} ->
        Access.record_block(scope, error)
        push_navigate(socket, to: ~p"/trainer/clients?limit=1")

      _other ->
        socket |> Access.flash_denial(error) |> push_navigate(to: ~p"/trainer/clients")
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:clients}>
      <.denied_sign :if={@denied} kind={elem(@denied, 0)} message={elem(@denied, 1)} />
      <div :if={!@denied && @form}>
        <.clients_form {assigns} />
      </div>
    </Layouts.app>
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
      /> <.input field={@form[:phone]} type="text" label="Phone" />
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

  @impl true
  def handle_event("validate", %{"client" => client_params}, socket) do
    changeset =
      case socket.assigns.live_action do
        :new -> User.registration_changeset(%User{}, client_params)
        :edit -> User.profile_changeset(socket.assigns.client, client_params)
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
        {:noreply, refuse(socket, error)}
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
        {:noreply, Access.flash_denial(socket, error)}
    end
  end
end
