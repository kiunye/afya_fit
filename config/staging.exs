import Config

# Staging-specific configuration
# This file is loaded only in staging environment

# Do not print debug messages in staging
config :logger, level: :info

# Staging database configuration
# Will be overridden by runtime.exs with environment variables or secrets
config :afya_fit, AfyaFit.Repo,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

# Staging endpoint configuration
config :afya_fit, AfyaFitWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  force_ssl: [hsts: true]

# Configures Swoosh API Client
config :swoosh, api_client: Swoosh.ApiClient.Req

# Disable Swoosh Local Memory Storage
config :swoosh, local: false
