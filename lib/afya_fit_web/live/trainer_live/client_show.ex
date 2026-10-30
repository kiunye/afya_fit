defmodule AfyaFitWeb.TrainerLive.ClientShow do
  @moduledoc """
  One client: their details and the way into their progress, workouts and nutrition.
  """
  use AfyaFitWeb, :live_view

  import AfyaFitWeb.SignComponents

  alias AfyaFit.Authorization
  alias AfyaFit.Authorization.Entitlements
  alias AfyaFit.Clients
  alias AfyaFitWeb.Access

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> Access.guard(:list, :client)
      |> assign(:page_title, "Clients")
      |> assign(:client, nil)
      |> assign(:can_upgrade?, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, %{assigns: %{denied: denied}} = socket) when denied != nil,
    do: {:noreply, socket}

  def handle_params(%{"id" => id}, _uri, socket) do
    scope = socket.assigns.current_scope

    case Clients.fetch_for(scope, :read, id) do
      {:ok, client} ->
        {:noreply,
         socket
         |> assign(:client, client)
         |> assign(:can_upgrade?, Authorization.can?(scope, :manage, :subscription))}

      error ->
        {:noreply, assign(socket, :denied, Access.denial(scope, error))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:clients}>
      <.denied_sign :if={@denied} kind={elem(@denied, 0)} message={elem(@denied, 1)} />
      <div :if={!@denied && @client}>
        <.clients_show {assigns} />
      </div>
    </Layouts.app>
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

          <:item title="Time zone">{AfyaFit.Timezone.zone(@client)}</:item>
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
end
