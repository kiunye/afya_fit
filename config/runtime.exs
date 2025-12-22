import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.
#
# Docker secrets are mounted at /run/secrets/<secret_name> and are read
# with priority over environment variables when available.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/afya_fit start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :afya_fit, AfyaFitWeb.Endpoint, server: true
end

# Runtime configuration for all environments
if config_env() in [:dev, :test] do
  # Development and test database configuration
  # Read from Docker secrets first, then environment variables
  db_password =
    cond do
      File.exists?("/run/secrets/db_password") ->
        "/run/secrets/db_password" |> File.read!() |> String.trim()

      System.get_env("DB_PASSWORD") ->
        System.get_env("DB_PASSWORD")

      true ->
        "postgres"
    end

  db_username = System.get_env("DB_USERNAME") || "postgres"
  db_host = System.get_env("DB_HOST") || "localhost"

  db_name =
    System.get_env("DB_NAME") || if config_env() == :dev, do: "afyafit_dev", else: "afyafit_test"

  config :afya_fit, AfyaFit.Repo,
    username: db_username,
    password: db_password,
    hostname: db_host,
    database: db_name,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  # Development and test endpoint configuration
  secret_key_base =
    cond do
      File.exists?("/run/secrets/secret_key_base") ->
        "/run/secrets/secret_key_base" |> File.read!() |> String.trim()

      System.get_env("SECRET_KEY_BASE") ->
        System.get_env("SECRET_KEY_BASE")

      config_env() == :dev ->
        "KCm/xtVpVU1X0iZs/GSv3CoUSfra/wWPuaCsuNnCAeI+Aguh+ZuASOi/sByUORWj"

      true ->
        "iC7C26RybH5Ibl/ng+j6QfurTgxHZjWWqdXe5GbrsWRu4gAVOs12Y+2I9GHJA6Bw"
    end

  host = System.get_env("PHX_HOST") || "localhost"

  port =
    String.to_integer(
      System.get_env("PORT") || if(config_env() == :dev, do: "4000", else: "4002")
    )

  config :afya_fit, AfyaFitWeb.Endpoint,
    url: [host: host],
    http: [ip: {127, 0, 0, 1}, port: port],
    secret_key_base: secret_key_base

  # Paystack configuration (for official Paystack library)
  # Read from Docker secrets first, then environment variables
  # In dev/test, it's optional (can be nil for testing without payments)
  paystack_secret_key =
    cond do
      File.exists?("/run/secrets/paystack_secret_key") ->
        "/run/secrets/paystack_secret_key" |> File.read!() |> String.trim()

      System.get_env("PAYSTACK_SECRET_KEY") ->
        System.get_env("PAYSTACK_SECRET_KEY")

      true ->
        nil
    end

  config :paystack, secret_key: paystack_secret_key
end

if config_env() == :prod do
  # Read from Docker secrets first, then environment variables
  database_url =
    cond do
      File.exists?("/run/secrets/database_url") ->
        "/run/secrets/database_url" |> File.read!() |> String.trim()

      System.get_env("DATABASE_URL") ->
        System.get_env("DATABASE_URL")

      true ->
        raise """
        environment variable DATABASE_URL or secret file /run/secrets/database_url is missing.
        For example: ecto://USER:PASS@HOST/DATABASE
        """
    end

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :afya_fit, AfyaFit.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable or Docker secret instead.
  secret_key_base =
    cond do
      File.exists?("/run/secrets/secret_key_base") ->
        "/run/secrets/secret_key_base" |> File.read!() |> String.trim()

      System.get_env("SECRET_KEY_BASE") ->
        System.get_env("SECRET_KEY_BASE")

      true ->
        raise """
        environment variable SECRET_KEY_BASE or secret file /run/secrets/secret_key_base is missing.
        You can generate one by calling: mix phx.gen.secret
        """
    end

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :afya_fit, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :afya_fit, AfyaFitWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # Paystack configuration (for official Paystack library)
  # Read from Docker secrets first, then environment variables
  paystack_secret_key =
    cond do
      File.exists?("/run/secrets/paystack_secret_key") ->
        "/run/secrets/paystack_secret_key" |> File.read!() |> String.trim()

      System.get_env("PAYSTACK_SECRET_KEY") ->
        System.get_env("PAYSTACK_SECRET_KEY")

      true ->
        raise """
        environment variable PAYSTACK_SECRET_KEY or secret file /run/secrets/paystack_secret_key is missing.
        Please set your Paystack secret key for payment processing.
        """
    end

  config :paystack, secret_key: paystack_secret_key
end

# ## SSL Support
#
# To get SSL working, you will need to add the `https` key
# to your endpoint configuration:
#
#     config :afya_fit, AfyaFitWeb.Endpoint,
#       https: [
#         ...,
#         port: 443,
#         cipher_suite: :strong,
#         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
#         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
#       ]
#
# The `cipher_suite` is set to `:strong` to support only the
# latest and more secure SSL ciphers. This means old browsers
# and clients may not be supported. You can set it to
# `:compatible` for wider support.
#
# `:keyfile` and `:certfile` expect an absolute path to the key
# and cert in disk or a relative path inside priv, for example
# "priv/ssl/server.key". For all supported SSL configuration
# options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
#
# We also recommend setting `force_ssl` in your config/prod.exs,
# ensuring no data is ever sent via http, always redirecting to https:
#
#     config :afya_fit, AfyaFitWeb.Endpoint,
#       force_ssl: [hsts: true]
#
# Check `Plug.SSL` for all available options in `force_ssl`.

# ## Configuring the mailer
#
# In production you need to configure the mailer to use a different adapter.
# Here is an example configuration for Mailgun:
#
#     config :afya_fit, AfyaFit.Mailer,
#       adapter: Swoosh.Adapters.Mailgun,
#       api_key: System.get_env("MAILGUN_API_KEY"),
#       domain: System.get_env("MAILGUN_DOMAIN")
#
# Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
# and Finch out-of-the-box. This configuration is typically done at
# compile-time in your config/prod.exs:
#
#     config :swoosh, :api_client, Swoosh.ApiClient.Req
#
# See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
