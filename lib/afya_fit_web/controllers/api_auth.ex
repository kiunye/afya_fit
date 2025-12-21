defmodule AfyaFitWeb.APIAuth do
  @moduledoc """
  Authentication plug for API endpoints.

  Expects a Bearer token in the Authorization header:
    Authorization: Bearer <token>

  The token should be a valid session token from UserToken.
  """
  import Plug.Conn
  import Phoenix.Controller
  alias AfyaFit.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case Accounts.get_user_by_session_token(token) do
          nil ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "Invalid or expired token"})
            |> halt()

          user ->
            assign(conn, :current_user, user)
        end

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Missing or invalid authorization header"})
        |> halt()
    end
  end

  @doc """
  Requires that a user is authenticated. Use this in pipelines.
  """
  def require_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Authentication required"})
      |> halt()
    end
  end

  @doc """
  Requires that the current user is a trainer. Use this in pipelines.
  """
  def require_trainer(conn, _opts) do
    user = conn.assigns[:current_user]

    if user && user.role == "trainer" do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Trainer access required"})
      |> halt()
    end
  end

  @doc """
  Requires that the current user is a trainer or admin. Use this in pipelines.
  """
  def require_trainer_or_admin(conn, _opts) do
    user = conn.assigns[:current_user]

    if user && user.role in ["trainer", "admin"] do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Trainer or admin access required"})
      |> halt()
    end
  end
end
