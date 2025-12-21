defmodule AfyaFitWeb.UserLive.Settings do
  use AfyaFitWeb, :live_view

  alias AfyaFit.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl space-y-12">
        <.header>Settings</.header>

        <div class="space-y-4">
          <.form for={@email_form} id="email_form" phx-submit="update_email">
            <.input field={@email_form[:email]} type="email" label="Email" required />
            <.input
              field={@email_form[:current_password]}
              name="current_password"
              id="email_form_current_password"
              type="password"
              label="Current password"
              value={@email_form_current_password}
              required
            />
            <div>
              <.button phx-disable-with="Changing...">Change Email</.button>
            </div>
          </.form>

          <.form for={@password_form} id="password_form" phx-submit="update_password" phx-change="validate_password">
            <input type="hidden" name="user[email]" value={@password_form[:email].value} id="hidden_user_email" />
            <.input field={@password_form[:password]} type="password" label="New password" required />
            <.input
              field={@password_form[:password_confirmation]}
              type="password"
              label="Confirm new password"
            />
            <.input
              field={@password_form[:current_password]}
              name="current_password"
              id="password_form_current_password"
              type="password"
              label="Current password"
              required
            />
            <div>
              <.button phx-disable-with="Changing...">Change Password</.button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:password_form_current_password, nil)
      |> assign_email_form(user)
      |> assign_password_form(user)

    {:ok, socket}
  end

  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, _params) do
    socket
  end

  defp apply_action(socket, :confirm_email, %{"token" => token}) do
    case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
      :error ->
        socket
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: ~p"/users/settings")

      {:ok, _} ->
        socket
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: ~p"/users/settings")
    end
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> Accounts.apply_user_email(password, user_params)

    {:noreply, assign(socket, email_form: to_form(email_form, as: "user"))}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_scope.user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign_email_form(user)}

      {:error, changeset} ->
        {:noreply, assign(socket, email_form: to_form(changeset, as: "user"))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> Accounts.User.validate_current_password(password)

    {:noreply, assign(socket, password_form: to_form(password_form, as: "user"))}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_scope.user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Password updated successfully.")
          |> assign_password_form(user)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset, as: "user"))}
    end
  end

  defp assign_email_form(socket, user) do
    assign(socket, email_form: to_form(Accounts.change_user_email(user), as: "user"))
  end

  defp assign_password_form(socket, user) do
    assign(socket, password_form: to_form(Accounts.change_user_password(user), as: "user"))
  end
end
