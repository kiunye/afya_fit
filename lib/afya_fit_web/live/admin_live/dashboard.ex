defmodule AfyaFitWeb.AdminLive.Dashboard do
  @moduledoc """
  Platform: every organization on Afya Fit, read-only, for platform admins.
  """
  use AfyaFitWeb, :live_view

  import AfyaFitWeb.SignComponents

  alias AfyaFit.Organizations
  alias AfyaFitWeb.Access

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> Access.guard(:access, :admin_panel)
      |> assign(:page_title, "Platform")

    if socket.assigns.denied do
      {:ok, socket}
    else
      organizations = Organizations.list_summaries()

      {:ok,
       socket
       |> assign(:count, length(organizations))
       |> stream(:organizations, organizations)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:platform}>
      <.denied_sign :if={@denied} kind={elem(@denied, 0)} message={elem(@denied, 1)} />
      <div :if={!@denied} id="platform">
        <.page_header>
          Platform
          <:subtitle>
            <b class="text-ink">
              {@count} {if @count == 1, do: "organisation", else: "organisations"}.
            </b>
            Read-only overview.
          </:subtitle>
        </.page_header>
        
        <.sign_group label="Organisations">
          <div id="organizations" phx-update="stream">
            <div id="organizations-empty" class="hidden px-4 py-6 text-ink-2 only:block sm:px-[26px]">
              No organisations yet.
            </div>
            
            <.sign
              :for={{id, org} <- @streams.organizations}
              id={id}
              icon={:platform}
              draw={false}
              time={to_string(org.clients)}
              time_label="Clients"
              overdue={org.status != "active"}
            >
              <:title>{org.name}</:title>
               {String.capitalize(org.plan_type)} plan · {org.trainers} {if org.trainers == 1,
                do: "trainer",
                else: "trainers"} · {org.status}
            </.sign>
          </div>
        </.sign_group>
      </div>
    </Layouts.app>
    """
  end
end
