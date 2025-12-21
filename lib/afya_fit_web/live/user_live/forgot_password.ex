defmodule AfyaFitWeb.UserLive.ForgotPassword do
  use AfyaFitWeb, :live_view

  alias AfyaFit.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <.header>
          Forgot your password?
          <:subtitle>
            We'll send a password reset link to your inbox
          </:subtitle>
        </.header>

        <.form for={@form} id="reset_password_form" phx-submit="send_email" class="space-y-4">
          <.input field={@form[:email]} type="email" placeholder="Email" required />
          <div>
            <.button phx-disable-with="Sending..." class="w-full">
              Send password reset instructions
            </.button>
          </div>
        </.form>
        <p class="mt-4 text-center text-sm">
          <.link navigate={~p"/users/log_in"}>Log in</.link>
        </p>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> assign(form: to_form(%{}, as: "user"))}
  end
end

