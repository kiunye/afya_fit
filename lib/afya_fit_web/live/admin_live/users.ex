defmodule AfyaFitWeb.AdminLive.Users do
  @moduledoc """
  Platform: find a person across organisations by name or email, to see which
  organisation and role they have. Read-only; there is no sign-in as someone else.
  """
  use AfyaFitWeb, :live_view

  import AfyaFitWeb.SignComponents

  alias AfyaFit.Platform
  alias AfyaFitWeb.Access

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> Access.guard(:access, :admin_panel)
      |> assign(:page_title, "Users")
      |> assign(:query, "")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    if socket.assigns.denied do
      {:noreply, socket}
    else
      query = params |> Map.get("q", "") |> String.trim()
      users = Platform.search_users(query)

      {:noreply,
       socket
       |> assign(:query, query)
       |> assign(:form, to_form(%{"q" => query}, as: :search))
       |> assign(:searched?, String.length(query) >= 2)
       |> assign(:empty?, users == [])
       |> stream(:users, users, reset: true)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:users}>
      <.denied_sign :if={@denied} kind={elem(@denied, 0)} message={elem(@denied, 1)} />

      <div :if={!@denied} id="users-page">
        <.page_header>
          Users
          <:subtitle>Search by name or email across every organisation.</:subtitle>
        </.page_header>

        <.sign_group label="Search">
          <.form
            for={@form}
            id="search-form"
            phx-change="search"
            phx-submit="search"
            class="max-w-xl px-4 pb-4 sm:px-[26px]"
          >
            <.input
              field={@form[:q]}
              type="search"
              label="Name or email"
              placeholder="At least two characters"
              phx-debounce="300"
            />
          </.form>

          <div id="users" phx-update="stream">
            <div id="users-empty" class="hidden px-4 py-6 text-ink-2 only:block sm:px-[26px]">
              {if @searched?, do: "No one matches.", else: "Type to search."}
            </div>
            <.sign :for={{id, person} <- @streams.users} id={id} icon={:team} draw={false}>
              <:title>{person.name}</:title>
              {person.email} · {role_text(person.role)} · {person.organization}
              <:actions>
                <.sign_action navigate={~p"/admin/organizations/#{person.organization_id}"}>
                  Organisation
                </.sign_action>
              </:actions>
            </.sign>
          </div>
        </.sign_group>
      </div>
    </Layouts.app>
    """
  end

  defp role_text("org_admin"), do: "Owner"
  defp role_text(role), do: String.capitalize(role)

  @impl true
  def handle_event("search", %{"search" => %{"q" => query}}, socket),
    do: {:noreply, push_patch(socket, to: ~p"/admin/users?#{%{q: query}}")}
end
