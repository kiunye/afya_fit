defmodule AfyaFitWeb.API.ClientController do
  use AfyaFitWeb, :controller

  alias AfyaFit.Accounts
  alias AfyaFit.Authorization
  alias AfyaFit.Clients

  # Authentication is handled in router pipeline

  action_fallback AfyaFitWeb.API.FallbackController

  def index(conn, params) do
    scope = conn.assigns.current_scope
    filters = if params["status"], do: %{status: params["status"]}, else: %{}

    with :ok <- Authorization.authorize(scope, :list, :client) do
      render(conn, :index, clients: Clients.list_clients_for(scope, filters))
    end
  end

  def create(conn, %{"client" => client_params}) do
    scope = conn.assigns.current_scope

    with :ok <- Authorization.authorize(scope, :create, :client),
         {:ok, client} <- Clients.create_client(scope.user, client_params) do
      conn
      |> put_status(:created)
      |> render(:show, client: client)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, client} <- fetch_client(conn, :read, id) do
      render(conn, :show, client: client)
    end
  end

  def update(conn, %{"id" => id, "client" => client_params}) do
    with {:ok, client} <- fetch_client(conn, :update, id),
         {:ok, client} <- Clients.update_client(client, client_params) do
      render(conn, :show, client: client)
    end
  end

  def delete(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    with {:ok, client} <- fetch_client(conn, :delete, id),
         {:ok, _links} <- Clients.archive_client_links(client, scope) do
      send_resp(conn, :no_content, "")
    end
  end

  def invite(conn, %{"id" => id}) do
    with {:ok, client} <- fetch_client(conn, :invite, id) do
      # TODO: Send invitation email (Phase 7)
      # For now, just return success
      render(conn, :show, client: client)
    end
  end

  defp fetch_client(conn, action, id) do
    client = Accounts.get_user!(id)

    with :ok <- Authorization.authorize(conn.assigns.current_scope, action, client),
         :ok <- ensure_client(client) do
      {:ok, client}
    end
  end

  # The user lookup is by id only; non-client users are not addressable here.
  defp ensure_client(%{role: "client"}), do: :ok
  defp ensure_client(_user), do: {:error, :not_found}
end
