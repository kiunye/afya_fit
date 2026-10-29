defmodule AfyaFitWeb.API.AuthController do
  use AfyaFitWeb, :controller

  alias AfyaFit.Accounts

  action_fallback AfyaFitWeb.API.FallbackController

  @doc """
  Authenticates a user and returns a session token.

  Expects JSON body:
  {
    "user": {
      "email": "user@example.com",
      "password": "password123"
    }
  }

  Returns JSON:
  {
    "user": { ... },
    "token": "session_token_here"
  }
  """
  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"401")

      user ->
        # Generate session token
        token = Accounts.generate_user_session_token(user)

        conn
        |> put_status(:ok)
        |> put_view(AfyaFitWeb.API.AuthView)
        |> render(:show, user: user, token: token)
    end
  end

  def show(conn, _params) do
    user = conn.assigns.current_user

    conn
    |> put_status(:ok)
    |> put_view(AfyaFitWeb.API.AuthView)
    |> render(:show, user: user, token: nil)
  end

  @doc """
  Registers a new user and returns a session token.

  Expects JSON body:
  {
    "user": {
      "email": "user@example.com",
      "password": "password123",
      "role": "trainer" | "client",
      "first_name": "John",
      "last_name": "Doe",
      "phone": "1234567890",
      "organization_name": "My Gym" (required for trainers),
      "organization_subdomain": "mygym" (required for trainers),
      "organization_subdomain": "existing-gym" (required for clients)
    }
  }

  Returns JSON:
  {
    "user": { ... },
    "token": "session_token_here"
  }
  """
  def register(conn, %{"user" => user_params}) do
    case Accounts.register_with_organization(user_params) do
      {:ok, user} ->
        # Generate session token
        token = Accounts.generate_user_session_token(user)

        # Send confirmation email
        Accounts.deliver_user_confirmation_instructions(
          user,
          &url(~p"/users/confirm/#{&1}")
        )

        conn
        |> put_status(:created)
        |> put_view(AfyaFitWeb.API.AuthView)
        |> render(:show, user: user, token: token)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"422", changeset: changeset)
    end
  end
end
