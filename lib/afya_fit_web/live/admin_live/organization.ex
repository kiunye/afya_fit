defmodule AfyaFitWeb.AdminLive.Organization do
  @moduledoc """
  Platform: one organization. Its plan, team and activity, and the two things a
  platform admin can do to it: suspend or reactivate it, and grant it a plan.
  """
  use AfyaFitWeb, :live_view

  import AfyaFitWeb.SignComponents

  alias AfyaFit.{Authorization, Platform}
  alias AfyaFitWeb.Access

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    socket =
      socket
      |> Access.guard(:access, :admin_panel)
      |> assign(:page_title, "Organisation")
      |> assign(:confirm_suspend?, false)
      |> assign(:grant_form, to_form(%{"plan" => "pro", "days" => "30"}, as: :grant))

    if socket.assigns.denied, do: {:ok, socket}, else: {:ok, load(socket, id)}
  end

  defp load(socket, id) do
    scope = socket.assigns.current_scope

    case Platform.get_organization(id) do
      {:ok, organization} ->
        socket
        |> assign(:overview, Platform.overview(organization))
        |> assign(:can_manage?, Authorization.can?(scope, :manage, :admin_panel))

      error ->
        assign(socket, :denied, Access.denial(scope, error))
    end
  end

  defp reload(socket), do: load(socket, socket.assigns.overview.organization.id)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:platform}>
      <.denied_sign :if={@denied} kind={elem(@denied, 0)} message={elem(@denied, 1)} />
      <div :if={!@denied} id="organization">
        <.page_header>
          {@overview.organization.name}
          <:subtitle>{@overview.organization.subdomain} · {@overview.organization.status}</:subtitle>
          
          <:actions>
            <.sign_action navigate={~p"/admin/dashboard"}>All organisations</.sign_action>
          </:actions>
        </.page_header>
        
        <.sign_group label="Plan">
          <.sign
            id="plan"
            icon={:billing}
            draw={false}
            overdue={@overview.organization.status != "active"}
            time={to_string(@overview.client_count)}
            time_label="Clients"
          >
            <:title>{String.capitalize(@overview.tier)} plan</:title>
             {subscription_text(@overview.subscription, @current_scope)}
          </.sign>
          
          <.form
            :if={@can_manage?}
            for={@grant_form}
            id="grant-form"
            phx-submit="grant"
            class="flex flex-wrap items-end gap-4 px-4 py-4 sm:px-[26px]"
          >
            <.input
              field={@grant_form[:plan]}
              type="select"
              label="Grant plan"
              options={for plan <- Platform.plans(), do: {String.capitalize(plan), plan}}
            />
            <.input
              field={@grant_form[:days]}
              type="select"
              label="For"
              options={for days <- Platform.grant_days(), do: {"#{days} days", to_string(days)}}
            /> <.button type="submit" variant="primary">Grant</.button>
          </.form>
        </.sign_group>
        
        <.sign_group :if={@can_manage?} label="Status">
          <.sign
            :if={@overview.organization.status == "active" && !@confirm_suspend?}
            id="status"
            icon={:platform}
            draw={false}
          >
            <:title>Active</:title>
            Suspending makes the organisation read-only until you reactivate it.
            <:actions>
              <.sign_action id="ask-suspend" phx-click="ask_suspend">Suspend</.sign_action>
            </:actions>
          </.sign>
          
          <.sign
            :if={@confirm_suspend?}
            id="suspend-confirm"
            icon={:alert}
            state={:next}
            draw={false}
          >
            <:title>Suspend {@overview.organization.name}?</:title>
            Their trainers and clients can still sign in and read everything, but nothing can be
            changed. This is recorded in their activity log.
            <:actions>
              <.sign_action id="confirm-suspend" primary phx-click="suspend">Suspend</.sign_action>
              
              <.sign_action id="keep-active" phx-click="cancel_suspend">Keep active</.sign_action>
            </:actions>
          </.sign>
          
          <.sign
            :if={@overview.organization.status != "active"}
            id="status"
            icon={:platform}
            draw={false}
            overdue
          >
            <:title>{String.capitalize(@overview.organization.status)}</:title>
            Read-only until reactivated.
            <:actions>
              <.sign_action id="reactivate" primary phx-click="reactivate">Reactivate</.sign_action>
            </:actions>
          </.sign>
        </.sign_group>
        
        <.sign_group label="Team">
          <.sign
            :for={member <- @overview.team}
            id={"member-#{member.id}"}
            icon={:team}
            draw={false}
          >
            <:title>{member.first_name} {member.last_name}</:title>
             {member.email} · {Access.role_label(member.role)}
          </.sign>
        </.sign_group>
        
        <.sign_group label="Recent activity">
          <div id="activity">
            <div :if={@overview.activity == []} class="px-4 py-6 text-ink-2 sm:px-[26px]">
              Nothing yet.
            </div>
            
            <.sign
              :for={entry <- @overview.activity}
              id={"activity-#{entry.id}"}
              icon={:alert}
              draw={false}
              time={local(entry.inserted_at, @current_scope, "%-d %b")}
              time_label="On"
            >
              <:title>{entry.action}</:title>
            </.sign>
          </div>
        </.sign_group>
      </div>
    </Layouts.app>
    """
  end

  defp subscription_text(nil, _scope), do: "No subscription."

  defp subscription_text(subscription, scope) do
    "#{String.capitalize(subscription.status)} · period ends " <>
      local(subscription.current_period_end, scope, "%-d %b %Y")
  end

  @impl true
  def handle_event("ask_suspend", _params, socket),
    do: {:noreply, assign(socket, :confirm_suspend?, true)}

  def handle_event("cancel_suspend", _params, socket),
    do: {:noreply, assign(socket, :confirm_suspend?, false)}

  def handle_event("suspend", _params, socket),
    do: change_status(socket, "suspended", "Suspended.")

  def handle_event("reactivate", _params, socket),
    do: change_status(socket, "active", "Reactivated.")

  def handle_event("grant", %{"grant" => %{"plan" => plan, "days" => days}}, socket) do
    scope = socket.assigns.current_scope
    organization = socket.assigns.overview.organization

    with {days, ""} <- Integer.parse(days),
         true <- plan in Platform.plans() and days in Platform.grant_days(),
         {:ok, _subscription} <- Platform.grant_plan(scope, organization, plan, days) do
      {:noreply,
       socket
       |> put_flash(:info, "#{String.capitalize(plan)} granted for #{days} days.")
       |> reload()}
    else
      {:error, _} = error -> {:noreply, Access.flash_denial(socket, error)}
      _ -> {:noreply, put_flash(socket, :error, "Choose a plan and a length of time.")}
    end
  end

  defp change_status(socket, status, message) do
    scope = socket.assigns.current_scope
    organization = socket.assigns.overview.organization

    case Platform.set_status(scope, organization, status) do
      {:ok, _} ->
        {:noreply,
         socket |> assign(:confirm_suspend?, false) |> put_flash(:info, message) |> reload()}

      error ->
        {:noreply, socket |> assign(:confirm_suspend?, false) |> Access.flash_denial(error)}
    end
  end
end
