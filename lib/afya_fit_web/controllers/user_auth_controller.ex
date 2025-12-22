defmodule AfyaFitWeb.UserAuthController do
  use AfyaFitWeb, :controller

  alias AfyaFit.Accounts
  alias AfyaFitWeb.UserAuth

  import Phoenix.Component

  plug UserAuth, action: :redirect_if_user_is_authenticated, only: [:create, :new]

  def new(conn, _params) do
    form = to_form(%{"email" => "", "password" => ""}, as: "user")
    render(conn, :new, form: form)
  end

  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
        if json_content_type?(conn) do
          conn
          |> put_status(:unauthorized)
          |> put_view(AfyaFitWeb.ErrorJSON)
          |> render(:"401")
        else
          form = to_form(%{"email" => email}, as: "user")

          conn
          |> put_flash(:error, "Invalid email or password")
          |> put_flash(:email, email)
          |> render(:new, form: form)
        end

      user ->
        if json_content_type?(conn) do
          # Return JSON response for API requests
          token = Accounts.generate_user_session_token(user)

          conn
          |> put_status(:ok)
          |> put_view(AfyaFitWeb.API.AuthView)
          |> render(:show, user: user, token: token)
        else
          # HTML response for web requests
          conn
          |> put_flash(:info, "Welcome back!")
          |> UserAuth.log_in_user(user, user_params)
        end
    end
  end

  defp json_content_type?(conn) do
    case get_req_header(conn, "accept") do
      [accept_header] -> String.contains?(accept_header, "application/json")
      _ -> false
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
