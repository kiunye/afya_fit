defmodule AfyaFitWeb.Router do
  use AfyaFitWeb, :router

  import AfyaFitWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AfyaFitWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  ## Authentication routes

  scope "/", AfyaFitWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{AfyaFitWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserLive.Register, :new
      live "/users/log_in", UserLive.Login, :new
      live "/users/reset_password", UserLive.ForgotPassword, :new
    end

    post "/users/log_in", UserAuthController, :create
  end

  scope "/", AfyaFitWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserAuthController, :delete

    live_session :current_user,
      on_mount: [{AfyaFitWeb.UserAuth, :mount_current_scope}] do
      live "/users/reset_password/:token", UserLive.ResetPassword, :edit
      live "/users/confirm/:token", UserLive.Confirm, :edit
      live "/users/confirm", UserLive.ConfirmInstructions, :show
      live "/", PageLive, :home
    end
  end

  ## Authenticated routes

  scope "/", AfyaFitWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{AfyaFitWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm_email/:token", UserLive.Settings, :confirm_email
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", AfyaFitWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:afya_fit, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AfyaFitWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
