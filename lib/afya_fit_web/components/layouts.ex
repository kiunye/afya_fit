defmodule AfyaFitWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use AfyaFitWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    user = if assigns.current_scope, do: assigns.current_scope.user, else: nil
    organization = if user && Ecto.assoc_loaded?(user.organization), do: user.organization, else: nil

    if user do
      authenticated_layout(assigns, user, organization)
    else
      unauthenticated_layout(assigns)
    end
  end

  defp get_logo_url(nil), do: nil
  defp get_logo_url(organization) do
    if organization.branding_config && is_map(organization.branding_config) do
      Map.get(organization.branding_config, "logo_url")
    else
      nil
    end
  end

  defp authenticated_layout(assigns, user, organization) do
    assigns =
      assigns
      |> assign(:user, user)
      |> assign(:logo_url, get_logo_url(organization))
      |> assign(:org_name, if(organization, do: organization.name, else: "Afya Fit"))

    ~H"""
    <div class="min-h-screen bg-gray-50 dark:bg-gray-900">
      <!-- Sidebar Navigation -->
      <aside
        id="sidebar"
        class="fixed inset-y-0 left-0 z-50 w-64 bg-white dark:bg-gray-800 border-r border-gray-200 dark:border-gray-700 transform transition-transform duration-300 ease-in-out lg:translate-x-0 -translate-x-full"
        phx-hook="Sidebar"
      >
        <div class="flex flex-col h-full">
          <!-- Logo/Branding -->
          <div class="flex items-center justify-between h-16 px-6 border-b border-gray-200 dark:border-gray-700">
            <a href={~p"/"} class="flex items-center gap-3">
              <%= if @logo_url do %>
                <img
                  src={@logo_url}
                  alt={@org_name}
                  class="h-8 w-8 rounded object-contain"
                />
              <% else %>
                <img
                  src={~p"/images/afya-fit-logo.png"}
                  alt="Afya Fit"
                  class="h-8 w-8 rounded object-contain"
                />
              <% end %>
              <span class="text-lg font-bold text-gray-900 dark:text-white">
                {@org_name}
              </span>
            </a>
            <button
              class="lg:hidden p-2 rounded-md text-gray-500 hover:text-gray-700 dark:hover:text-gray-300"
              onclick="window.toggleSidebar && window.toggleSidebar()"
              data-sidebar-toggle
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>

          <!-- Navigation Menu -->
          <nav class="flex-1 px-4 py-6 space-y-1 overflow-y-auto">
            <%= if @user.role == "trainer" do %>
              <.nav_link navigate={~p"/trainer/dashboard"} label="Dashboard" icon="hero-home" />
              <.nav_link navigate={~p"/trainer/clients"} label="Clients" icon="hero-users" />
              <.nav_link navigate={~p"/trainer/workouts"} label="Workouts" icon="hero-bolt" />
              <.nav_link navigate={~p"/trainer/nutrition"} label="Nutrition" icon="hero-cake" />
              <.nav_link navigate={~p"/trainer/progress"} label="Progress" icon="hero-chart-bar" />
            <% else %>
              <.nav_link navigate={~p"/"} label="Home" icon="hero-home" />
            <% end %>
            <div class="pt-4 mt-4 border-t border-gray-200 dark:border-gray-700">
              <%= if @user.role == "trainer" do %>
                <.nav_link navigate={~p"/trainer/subscription"} label="Subscription" icon="hero-credit-card" />
              <% end %>
              <.nav_link navigate={~p"/users/settings"} label="Settings" icon="hero-cog-6-tooth" />
            </div>
          </nav>

          <!-- User Profile Footer -->
          <div class="p-4 border-t border-gray-200 dark:border-gray-700">
            <div class="flex items-center gap-3 mb-3">
              <%= if @user.avatar_url do %>
                <img
                  src={@user.avatar_url}
                  alt={"#{@user.first_name} #{@user.last_name}"}
                  class="h-10 w-10 rounded-full"
                />
              <% else %>
                <div class="h-10 w-10 rounded-full flex items-center justify-center">
                  <.icon name="hero-user-circle" class="w-8 h-8 text-gray-600 dark:text-gray-400" />
                </div>
              <% end %>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-gray-900 dark:text-white truncate">
                  {@user.first_name} {@user.last_name}
                </p>
                <p class="text-xs text-gray-500 dark:text-gray-400 truncate">{@user.email}</p>
              </div>
            </div>
            <form action={~p"/users/log_out"} method="post" class="w-full">
              <input type="hidden" name="_method" value="delete" />
              <input type="hidden" name={get_csrf_token()} value={get_csrf_token()} />
              <button
                type="submit"
                class="w-full flex items-center gap-2 px-3 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-md transition-colors"
              >
                <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4" />
                Sign out
              </button>
            </form>
          </div>
        </div>
      </aside>

      <!-- Main Content Area -->
      <div class="lg:pl-64">
        <!-- Top Bar -->
        <header class="sticky top-0 z-40 flex h-16 shrink-0 items-center gap-x-4 border-b border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 px-4 shadow-sm sm:gap-x-6 sm:px-6 lg:px-8">
          <button
            type="button"
            class="-m-2.5 p-2.5 text-gray-700 dark:text-gray-300 lg:hidden"
            onclick="window.toggleSidebar && window.toggleSidebar()"
            data-sidebar-toggle
          >
            <.icon name="hero-bars-3" class="h-6 w-6" />
          </button>

          <div class="flex flex-1 gap-x-4 self-stretch lg:gap-x-6">
            <div class="flex flex-1 items-center gap-x-4 lg:gap-x-6">
              <!-- Search or other top bar content can go here -->
            </div>
            <div class="flex items-center gap-x-4 lg:gap-x-6">
              <.theme_toggle />
            </div>
          </div>
        </header>

        <!-- Page Content -->
        <main class="py-8">
          <div class="px-4 sm:px-6 lg:px-8">
            {render_slot(@inner_block)}
          </div>
        </main>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  defp unauthenticated_layout(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 dark:from-gray-900 dark:to-gray-800">
      <!-- Simple Header for Unauthenticated Users -->
      <header class="bg-white dark:bg-gray-800 shadow-sm">
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="flex h-16 items-center justify-between">
            <a href={~p"/"} class="flex items-center gap-2">
              <img
                src={~p"/images/afya-fit-logo.png"}
                alt="Afya Fit"
                class="h-8 w-8 rounded object-contain"
              />
              <span class="text-xl font-bold text-gray-900 dark:text-white">Afya Fit</span>
            </a>
            <div class="flex items-center gap-4">
              <.theme_toggle />
              <%= if !assigns.current_scope || !assigns.current_scope.user do %>
                <div class="flex items-center gap-2">
                  <.link
                    navigate={~p"/users/log_in"}
                    class="px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-white"
                  >
                    Sign in
                  </.link>
                  <.link
                    navigate={~p"/users/register"}
                    class="px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-md transition-colors"
                  >
                    Get started
                  </.link>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </header>

      <!-- Main Content -->
      <main class="flex-1">
        {render_slot(@inner_block)}
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  attr :navigate, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :active, :boolean, default: false

  defp nav_link(assigns) do
    ~H"""
    <a
      href={@navigate}
      class={[
        "flex items-center gap-3 px-3 py-2 text-sm font-medium rounded-md transition-colors",
        @active &&
          "bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-400" ||
          "text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700"
      ]}
    >
      <.icon name={@icon} class="w-5 h-5" />
      <span>{@label}</span>
    </a>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/2 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=dark]_&]:left-1/2 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/2"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/2"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
