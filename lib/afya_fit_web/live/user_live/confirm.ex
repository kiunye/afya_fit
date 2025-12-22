defmodule AfyaFitWeb.UserLive.Confirm do
  use AfyaFitWeb, :live_view

  alias AfyaFit.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <.header>Confirm your account</.header>

        <p :if={@current_user}>
          Account confirmed successfully.
          <.link navigate={~p"/users/log_in"} class="font-semibold text-brand hover:underline">
            Sign in
          </.link>
          now.
        </p>

        <p :if={!@current_user}>
          We are unable to confirm your account. It may be already confirmed, or the link may have expired.
        </p>
      </div>
    </Layouts.app>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    {:ok, assign(socket, token: token, error: nil)}
  end

  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"token" => token}) do
    case Accounts.confirm_user(token) do
      {:ok, _} ->
        assign(socket, current_user: true)

      :error ->
        assign(socket, current_user: false)
    end
  end
end


