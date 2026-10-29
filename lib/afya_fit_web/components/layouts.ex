defmodule AfyaFitWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use AfyaFitWeb, :html

  import AfyaFitWeb.SignComponents

  alias AfyaFit.Authorization.Scope
  alias AfyaFitWeb.Access

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  Signed-in users get the sign-system shell: a sidebar on desktop, a bottom
  tab bar on phones, and the account banner above the page. Visitors get the
  public header. Pass `active` (a navigation key such as `:clients`) so the
  current item is marked.

  ## Examples

      <Layouts.app flash={@flash} current_scope={@current_scope} active={:clients}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :is_homepage, :boolean, default: false, doc: "whether this is the homepage"
  attr :active, :atom, default: nil, doc: "the navigation key of the current page"

  slot :inner_block, required: true

  def app(assigns) do
    case assigns.current_scope do
      %Scope{} = scope -> authenticated_layout(assign(assigns, :scope, scope))
      _ -> unauthenticated_layout(assigns)
    end
  end

  defp authenticated_layout(assigns) do
    items = Access.nav_items(assigns.scope)

    assigns =
      assigns
      |> assign(:items, items)
      |> assign(:more_items, Enum.filter(items, &(&1.phone == :more)))
      |> assign(:banner, Access.banner(assigns.scope))
      |> assign(:org_name, org_name(assigns.scope))
      |> assign(:logo_url, logo_url(assigns.scope.organization))

    ~H"""
    <a
      href="#main"
      class="sr-only focus:not-sr-only focus:fixed focus:left-2 focus:top-2 focus:z-50 focus:bg-paper focus:px-3 focus:py-2 focus:text-field-0"
    >
      Skip to content
    </a>
    <div class="min-h-screen bg-field-1 pb-[78px] text-ink md:grid md:grid-cols-[72px_1fr] md:pb-0 lg:grid-cols-[132px_1fr]">
      <nav
        id="sidebar"
        aria-label="Main"
        class="hidden border-r-[3px] border-line bg-field-0 md:sticky md:top-0 md:flex md:h-screen md:flex-col md:overflow-y-auto"
      >
        <.link
          navigate={~p"/"}
          class="flex flex-col items-center gap-1.5 border-b-[1.5px] border-line/40 px-1.5 py-3 text-center"
        >
          <img
            :if={@logo_url}
            src={@logo_url}
            alt=""
            class="size-8 rounded-control object-contain"
          />
          <img
            :if={!@logo_url}
            src={~p"/images/afya-fit-logo.png"}
            alt=""
            class="size-8 rounded-control object-contain"
          />
          <span class="hidden max-w-full truncate text-xs font-bold lg:block">{@org_name}</span>
          <span class="sr-only lg:hidden">{@org_name}</span>
        </.link>
        <.side_link :for={item <- @items} item={item} active={@active} />
        <div class="mt-auto border-t-[1.5px] border-line/40">
          <.side_link item={settings_item()} active={@active} />
          <div class="hidden px-2.5 py-3 text-xs leading-tight text-ink-2 lg:block">
            <b class="block truncate font-bold text-ink">
              {@scope.user.first_name} {@scope.user.last_name}
            </b>
            {role_label(@scope)} · {plan_label(@scope)}
          </div>
          <form action={~p"/users/log_out"} method="post" class="px-2 pb-3">
            <input type="hidden" name="_method" value="delete" />
            <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
            <button
              type="submit"
              class="w-full cursor-pointer rounded-control px-1 py-2 text-xs font-bold uppercase tracking-[.06em] text-ink-2 hover:bg-field-2 hover:text-white focus-visible:outline-3 focus-visible:outline-white"
            >
              Sign out
            </button>
          </form>
        </div>
      </nav>

      <div class="min-w-0">
        <.account_banner :if={@banner} state={@banner.state}>
          {@banner.message}
          <:action :if={@banner.action == :update_payment}>
            <.link navigate={~p"/billing"}>Update payment</.link>
          </:action>
          <:action :if={match?({:ask, _}, @banner.action)}>
            {elem(@banner.action, 1)} can fix this
          </:action>
        </.account_banner>
        <main id="main">
          {render_slot(@inner_block)}
        </main>
      </div>

      <nav
        aria-label="Main"
        class="fixed inset-x-0 bottom-0 z-30 flex border-t-[3px] border-line bg-field-0 md:hidden"
      >
        <.tab_link
          :for={item <- Enum.filter(@items, &(&1.phone == :tab))}
          item={item}
          active={@active}
        />
        <button
          type="button"
          aria-controls="more-sheet"
          phx-click={JS.toggle(to: "#more-sheet", display: "block")}
          class="flex min-h-[60px] flex-1 cursor-pointer flex-col items-center justify-center gap-0.5 px-0.5 py-2 text-xs font-bold uppercase tracking-[.02em] text-ink-2 focus-visible:outline-3 focus-visible:outline-white"
        >
          <.pictogram name={:more} class="size-7" />
          <span>More</span>
        </button>
      </nav>

      <div
        id="more-sheet"
        class="fixed inset-x-0 bottom-[66px] z-30 hidden border-t-[3px] border-field-0 bg-paper text-field-0 md:hidden"
      >
        <.link
          :for={item <- @more_items ++ [settings_item()]}
          navigate={item.path}
          class="flex items-center gap-4 border-b border-field-0/20 px-4 py-3.5 text-base font-bold focus-visible:outline-3 focus-visible:outline-field-0"
        >
          <.pictogram name={item.icon} class="size-8" />
          {item.label}
        </.link>
        <form action={~p"/users/log_out"} method="post">
          <input type="hidden" name="_method" value="delete" />
          <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
          <button
            type="submit"
            class="w-full cursor-pointer px-4 py-3.5 text-left text-base font-bold focus-visible:outline-3 focus-visible:outline-field-0"
          >
            Sign out
          </button>
        </form>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  attr :item, :map, required: true
  attr :active, :atom, default: nil

  defp side_link(assigns) do
    ~H"""
    <.link
      navigate={@item.path}
      aria-current={@active == @item.key && "page"}
      title={@item.label}
      class={[
        "relative flex flex-col items-center gap-1.5 border-b-[1.5px] border-line/40 px-1.5 py-3.5",
        "text-xs font-bold uppercase tracking-[.06em] focus-visible:outline-3 focus-visible:-outline-offset-4 focus-visible:outline-white",
        @active == @item.key && "bg-paper text-field-0",
        @active != @item.key && "text-ink-2 hover:bg-field-2 hover:text-white"
      ]}
    >
      <.pictogram name={@item.icon} class="size-9" />
      <span class="sr-only lg:not-sr-only">{@item.label}</span>
      <span
        :if={@item.pro}
        class="absolute right-1.5 top-1.5 rounded-[3px] border-2 border-current px-1 text-xs leading-4"
      >
        Pro
      </span>
    </.link>
    """
  end

  attr :item, :map, required: true
  attr :active, :atom, default: nil

  defp tab_link(assigns) do
    ~H"""
    <.link
      navigate={@item.path}
      aria-current={@active == @item.key && "page"}
      class={[
        "flex min-h-[60px] flex-1 flex-col items-center justify-center gap-0.5 px-0.5 py-2",
        "text-xs font-bold uppercase tracking-[.02em] focus-visible:outline-3 focus-visible:-outline-offset-4 focus-visible:outline-white",
        @active == @item.key && "bg-paper text-field-0",
        @active != @item.key && "text-ink-2"
      ]}
    >
      <.pictogram name={@item.icon} class="size-7" />
      <span>{@item.label}</span>
    </.link>
    """
  end

  defp settings_item,
    do: %{
      key: :settings,
      label: "Settings",
      icon: :settings,
      path: "/users/settings",
      pro: false,
      phone: :more
    }

  defp org_name(%Scope{organization: %{name: name}}), do: name
  defp org_name(_scope), do: "Afya Fit"

  defp logo_url(%{branding_config: %{"logo_url" => url}}) when is_binary(url), do: url
  defp logo_url(_organization), do: nil

  defp role_label(scope) do
    case Scope.role(scope) do
      :org_admin -> "Owner"
      :trainer -> "Trainer"
      :client -> "Client"
      :admin -> "Platform"
      _ -> "User"
    end
  end

  defp plan_label(%Scope{tier: tier}), do: String.capitalize("#{tier} plan")

  defp unauthenticated_layout(assigns) do
    is_homepage = Map.get(assigns, :is_homepage, false)

    ~H"""
    <div class={[
      "min-h-screen",
      @is_homepage && "bg-gradient-to-br from-black via-slate-950 to-black",
      !@is_homepage &&
        "bg-gradient-to-br from-gray-50 to-gray-100 dark:from-gray-900 dark:to-gray-800"
    ]}>
      <!-- Simple Header for Unauthenticated Users -->
      <header class={[
        "sticky top-0 z-50 transition-all duration-300",
        @is_homepage && "bg-white/5 backdrop-blur-md border-b border-white/10",
        !@is_homepage && "bg-white dark:bg-gray-800 shadow-sm"
      ]}>
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="flex h-16 items-center justify-between">
            <a href={~p"/"} class="flex items-center gap-2">
              <img
                src={~p"/images/afya-fit-logo.png"}
                alt="Afya Fit"
                class="h-8 w-8 rounded object-contain"
              />
              <span class={[
                "text-xl font-bold",
                @is_homepage && "text-white",
                !@is_homepage && "text-gray-900 dark:text-white"
              ]}>
                Afya Fit
              </span>
            </a>
            <div class="flex items-center gap-4">
              <%= unless @is_homepage do %>
                <.theme_toggle />
              <% end %>
              <div class="flex items-center gap-2">
                <.link
                  navigate={~p"/users/log_in"}
                  class={[
                    "px-4 py-2 text-sm font-medium rounded-md transition-colors",
                    @is_homepage && "text-white hover:text-gray-200",
                    !@is_homepage &&
                      "text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-white"
                  ]}
                >
                  Sign in
                </.link>
                <.link
                  navigate={~p"/users/register"}
                  class={[
                    "px-4 py-2 text-sm font-medium rounded-md transition-colors",
                    @is_homepage &&
                      "text-white bg-white/10 hover:bg-white/20 border border-white/20",
                    !@is_homepage && "text-white bg-blue-600 hover:bg-blue-700"
                  ]}
                >
                  Get started
                </.link>
              </div>
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
  Provides dark vs light theme toggle for the public pages.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative flex flex-row items-center rounded-full border-2 border-base-300 bg-base-300">
      <div class="absolute left-0 h-full w-1/2 rounded-full border border-base-200 bg-base-100 brightness-200 transition-[left] [[data-theme=dark]_&]:left-1/2" />

      <button
        class="flex w-1/2 cursor-pointer p-2"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        aria-label="Light theme"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex w-1/2 cursor-pointer p-2"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        aria-label="Dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
