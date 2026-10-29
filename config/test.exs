import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
# Jobs are enqueued but never run in tests; assert on them with Oban.Testing.
config :afya_fit, Oban, testing: :manual

# `RLS_ENFORCE=true mix test` runs the suite as the non-owner role. Tests switch
# role inside the sandbox transaction, so migrations still run as the owner.
config :afya_fit, AfyaFit.RLS,
  enforce: System.get_env("RLS_ENFORCE") == "true",
  app_role: "afya_fit_app",
  role_on_connect: false,
  restore_context: true

config :afya_fit, AfyaFit.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  hostname: System.get_env("POSTGRES_HOST") || System.get_env("DB_HOST") || "localhost",
  database:
    System.get_env("POSTGRES_DB") || "afya_fit_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  # LiveView and API tests run in parallel; wait for a connection instead of failing.
  queue_target: 5_000,
  queue_interval: 5_000

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :afya_fit, AfyaFitWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4002")],
  secret_key_base:
    System.get_env("SECRET_KEY_BASE") ||
      "iC7C26RybH5Ibl/ng+j6QfurTgxHZjWWqdXe5GbrsWRu4gAVOs12Y+2I9GHJA6Bw",
  server: false

# In test we don't send emails
config :afya_fit, AfyaFit.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
