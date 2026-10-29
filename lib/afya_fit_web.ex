defmodule AfyaFitWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use AfyaFitWeb, :controller
      use AfyaFitWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      use Gettext, backend: AfyaFitWeb.Gettext

      import Plug.Conn

      # Run the action inside the requester's tenant context for row-level security.
      def action(conn, _opts) do
        AfyaFit.Repo.with_scope(conn.assigns[:current_scope], fn ->
          apply(__MODULE__, action_name(conn), [conn, conn.params])
        end)
      rescue
        # With RLS on, another tenant's rows do not exist for this request, so a
        # missing record is the same "not found" the policies would have given.
        Ecto.NoResultsError ->
          if AfyaFit.Repo.enforce?() do
            conn
            |> put_status(:not_found)
            |> put_view(html: AfyaFitWeb.ErrorHTML, json: AfyaFitWeb.ErrorJSON)
            |> render(:"404")
          else
            reraise Ecto.NoResultsError, __STACKTRACE__
          end
      end

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView
      use AfyaFit.Repo.Wrap, :live_view

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: AfyaFitWeb.Gettext

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      import AfyaFitWeb.CoreComponents

      # Common modules used in templates
      alias AfyaFitWeb.Layouts
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: AfyaFitWeb.Endpoint,
        router: AfyaFitWeb.Router,
        statics: AfyaFitWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
