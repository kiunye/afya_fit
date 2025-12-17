# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# Load .env file if it exists (for development/test)
if File.exists?(".env") do
  File.stream!(".env")
  |> Stream.map(&String.trim/1)
  |> Stream.reject(&(&1 == "" or String.starts_with?(&1, "#")))
  |> Stream.map(&String.split(&1, "=", parts: 2))
  |> Enum.each(fn
    [key, value] -> System.put_env(key, String.replace(value, ~r/^"|"$/, ""))
    _ -> :ok
  end)
end

# General application configuration
import Config

config :afya_fit,
  ecto_repos: [AfyaFit.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configures the endpoint
config :afya_fit, AfyaFitWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST") || "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AfyaFitWeb.ErrorHTML, json: AfyaFitWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: AfyaFit.PubSub,
  live_view: [signing_salt: System.get_env("PHX_SIGNING_SALT") || "j0HPcR1r"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :afya_fit, AfyaFit.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  afya_fit: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  afya_fit: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
