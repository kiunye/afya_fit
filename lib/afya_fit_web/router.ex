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

  pipeline :api_auth do
    plug AfyaFitWeb.APIAuth
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

      # Trainer routes
      live "/trainer/dashboard", TrainerLive.Dashboard, :index
      live "/trainer/clients", TrainerLive.Clients, :index
      live "/trainer/clients/new", TrainerLive.Clients, :new
      live "/trainer/clients/:id", TrainerLive.Clients, :show
      live "/trainer/clients/:id/edit", TrainerLive.Clients, :edit

      # Workout plans
      live "/trainer/workouts", TrainerLive.Workouts, :index
      live "/trainer/workouts/new", TrainerLive.Workouts, :new
      live "/trainer/workouts/:id", TrainerLive.Workouts, :show
      live "/trainer/workouts/:id/edit", TrainerLive.Workouts, :edit

      # Nutrition plans
      live "/trainer/nutrition", TrainerLive.Nutrition, :index
      live "/trainer/nutrition/new", TrainerLive.Nutrition, :new
      live "/trainer/nutrition/:id", TrainerLive.Nutrition, :show
      live "/trainer/nutrition/:id/edit", TrainerLive.Nutrition, :edit

      # Progress tracking
      live "/trainer/progress", TrainerLive.Progress, :index
      live "/trainer/progress/:client_id", TrainerLive.Progress, :client
    end
  end

  ## API routes

  scope "/api/v1", AfyaFitWeb.API do
    pipe_through [:api, :api_auth]

    # Clients
    get "/clients", ClientController, :index
    post "/clients", ClientController, :create
    get "/clients/:id", ClientController, :show
    put "/clients/:id", ClientController, :update
    delete "/clients/:id", ClientController, :delete
    post "/clients/:id/invite", ClientController, :invite
    get "/clients/:id/progress", ProgressController, :index

    # Workout Plans
    get "/workout-plans", WorkoutPlanController, :index
    post "/workout-plans", WorkoutPlanController, :create
    get "/workout-plans/templates", WorkoutPlanController, :templates
    get "/workout-plans/:id", WorkoutPlanController, :show
    put "/workout-plans/:id", WorkoutPlanController, :update
    delete "/workout-plans/:id", WorkoutPlanController, :delete
    post "/workout-plans/:id/duplicate", WorkoutPlanController, :duplicate

    # Client Workouts
    get "/clients/:client_id/workouts", ClientWorkoutController, :index
    post "/clients/:client_id/workouts", ClientWorkoutController, :create
    put "/client-workouts/:id", ClientWorkoutController, :update
    delete "/client-workouts/:id", ClientWorkoutController, :delete
    post "/client-workouts/:id/complete", ClientWorkoutController, :complete

    # Nutrition Plans
    get "/nutrition-plans", NutritionPlanController, :index
    post "/nutrition-plans", NutritionPlanController, :create
    get "/nutrition-plans/:id", NutritionPlanController, :show
    put "/nutrition-plans/:id", NutritionPlanController, :update
    delete "/nutrition-plans/:id", NutritionPlanController, :delete
    get "/clients/:client_id/nutrition", NutritionPlanController, :client_nutrition

    # Progress Tracking
    get "/clients/:client_id/progress", ProgressController, :index
    post "/clients/:client_id/progress", ProgressController, :create
    get "/progress/:id", ProgressController, :show
    put "/progress/:id", ProgressController, :update
    delete "/progress/:id", ProgressController, :delete
    get "/clients/:client_id/progress/analytics", ProgressController, :analytics

    # Tasks
    get "/tasks", TaskController, :index
    post "/tasks", TaskController, :create
    post "/tasks/bulk", TaskController, :bulk
    get "/tasks/:id", TaskController, :show
    put "/tasks/:id", TaskController, :update
    delete "/tasks/:id", TaskController, :delete
    post "/tasks/:id/complete", TaskController, :complete
    get "/clients/:client_id/tasks", TaskController, :client_tasks

    # Calendar
    get "/calendar/events", CalendarController, :index
    post "/calendar/events", CalendarController, :create
    get "/calendar/events/:id", CalendarController, :show
    put "/calendar/events/:id", CalendarController, :update
    delete "/calendar/events/:id", CalendarController, :delete
    get "/calendar/upcoming", CalendarController, :upcoming
  end

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
