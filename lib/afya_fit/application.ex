defmodule AfyaFit.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AfyaFitWeb.Telemetry,
      AfyaFit.Repo,
      {DNSCluster, query: Application.get_env(:afya_fit, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AfyaFit.PubSub},
      # Start a worker by calling: AfyaFit.Worker.start_link(arg)
      # {AfyaFit.Worker, arg},
      # Start to serve requests, typically the last entry
      AfyaFitWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AfyaFit.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AfyaFitWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
