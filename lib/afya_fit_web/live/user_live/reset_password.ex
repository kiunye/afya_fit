defmodule AfyaFitWeb.UserLive.ResetPassword do
  use AfyaFitWeb, :live_view

  alias AfyaFit.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <.header>Reset password</.header>

        <.form
          for={@form}
          id="reset_password_form"
          phx-change="validate"
          phx-submit="reset_password"
        >
          <.input field={@form[:password]} type="password" label="New password" required />
          <.input
            field={@form[:password_confirmation]}
            type="password"
            label="Confirm new password"
          />
          <div>
            <.button phx-disable-with="Resetting password..." class="w-full">Reset password</.button>
          </div>
        </.form>
        <p class="mt-4 text-center text-sm">
          <.link navigate={~p"/users/log_in"}>Log in</.link>
        </p>
      </div>
    </Layouts.app>
    """
  end

  def mount(params, _session, socket) do
    socket = assign_user_by_token(socket, params)

    socket =
      case socket.assigns do
        %{user: user} ->
          assign(socket, form: to_form(Accounts.change_user_password(user)))

        _ ->
          socket
      end

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_password(socket.assigns.user, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password(socket.assigns.user, user_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully.")
         |> redirect(to: ~p"/users/log_in")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_user_by_token(socket, %{"token" => token}) do
    case Accounts.get_user_by_reset_password_token(token) do
      nil ->
        socket
        |> put_flash(:error, "Reset password link is invalid or it has expired.")
        |> redirect(to: ~p"/")

      user ->
        assign(socket, user: user, token: token)
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end

