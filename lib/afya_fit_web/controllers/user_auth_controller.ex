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

    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      form = to_form(%{"email" => email}, as: "user")
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, email)
      |> render(:new, form: form)
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end

