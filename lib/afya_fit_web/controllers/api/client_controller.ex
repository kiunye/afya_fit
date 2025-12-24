defmodule AfyaFitWeb.API.ClientController do
  use AfyaFitWeb, :controller

  alias AfyaFit.Accounts
  alias AfyaFit.Clients

  # Authentication is handled in router pipeline

  action_fallback AfyaFitWeb.API.FallbackController

  def index(conn, params) do
    current_user = conn.assigns.current_user
    filters = Map.take(params, ["status"])

    clients =
      case current_user.role do
        "trainer" ->
          Clients.list_trainer_clients(current_user.id, filters)
          |> Enum.map(& &1.client)

        "admin" ->
          Clients.list_organization_clients(current_user.organization_id, filters)
      end

    render(conn, :index, clients: clients)
  end

  def create(conn, %{"client" => client_params}) do
    current_user = conn.assigns.current_user

    case Clients.create_client(current_user, client_params) do
      {:ok, client} ->
        conn
        |> put_status(:created)
        |> render(:show, client: client)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"422", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    client =
      case current_user.role do
        "trainer" -> Clients.get_client!(current_user, id)
        "admin" -> Accounts.get_user!(id)
        _ -> raise Ecto.NoResultsError
      end

    render(conn, :show, client: client)
  end

  def update(conn, %{"id" => id, "client" => client_params}) do
    current_user = conn.assigns.current_user
    client = Clients.get_client!(current_user, id)

    case Clients.update_client(client, client_params) do
      {:ok, client} ->
        render(conn, :show, client: client)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"422", changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    trainer_client = Clients.get_trainer_client_by_ids(current_user.id, id)

    case Clients.archive_trainer_client(trainer_client) do
      {:ok, _trainer_client} ->
        send_resp(conn, :no_content, "")

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"422", changeset: changeset)
    end
  end

  def invite(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    client = Clients.get_client!(current_user, id)

    # TODO: Send invitation email (Phase 7)
    # For now, just return success
    render(conn, :show, client: client)
  end
end
