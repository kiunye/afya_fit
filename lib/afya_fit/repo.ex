defmodule AfyaFit.Repo do
  use Ecto.Repo,
    otp_app: :afya_fit,
    adapter: Ecto.Adapters.Postgres

  @impl true
  def init(_type, config), do: {:ok, AfyaFit.RLS.connection_config(config)}
end
