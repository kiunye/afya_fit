defmodule AfyaFitWeb.API.AuthController do
  use AfyaFitWeb, :controller

  alias AfyaFit.Accounts
  alias AfyaFit.Organizations

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
  @dialyzer {:nowarn_function, register: 2}
  def register(conn, %{"user" => user_params}) do
    case register_user_with_organization(user_params) do
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

      {:error, :organization, changeset, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"422", changeset: changeset)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"422", changeset: changeset)
    end
  end

  @dialyzer {:nowarn_function, register_user_with_organization: 1}
  defp register_user_with_organization(%{"role" => "trainer"} = user_params) do
    # Trainers create their own organization
    org_attrs = %{
      "name" => user_params["organization_name"],
      "subdomain" => user_params["organization_subdomain"],
      "plan_type" => "free",
      "status" => "active"
    }

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :organization,
      Organizations.Organization.changeset(%Organizations.Organization{}, org_attrs)
    )
    |> Ecto.Multi.insert(:user, fn %{organization: org} ->
      Accounts.User.registration_changeset(
        %Accounts.User{},
        Map.put(user_params, "organization_id", org.id)
      )
    end)
    |> AfyaFit.Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :organization, changeset, _} -> {:error, :organization, changeset, %{}}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  defp register_user_with_organization(%{"role" => "client"} = user_params) do
    # Clients join an existing organization by subdomain
    subdomain = user_params["organization_subdomain"]

    case Organizations.get_organization_by_subdomain(subdomain) do
      nil ->
        changeset =
          Accounts.User.registration_changeset(%Accounts.User{}, user_params)
          |> Ecto.Changeset.add_error(:organization_subdomain, "not found")

        {:error, changeset}

      organization ->
        user_params
        |> Map.put("organization_id", organization.id)
        |> Accounts.register_user()
    end
  end

  defp register_user_with_organization(user_params) do
    # Fallback for other roles
    Accounts.register_user(user_params)
  end
end
