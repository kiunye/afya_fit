defmodule AfyaFit.Repo do
  use Ecto.Repo,
    otp_app: :afya_fit,
    adapter: Ecto.Adapters.Postgres
end
