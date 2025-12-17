import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :afya_fit, AfyaFit.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "afya_fit_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

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
