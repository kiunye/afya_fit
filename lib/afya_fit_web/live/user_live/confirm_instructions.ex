defmodule AfyaFitWeb.UserLive.ConfirmInstructions do
  use AfyaFitWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <.header>Check your email</.header>
        <p>
          If your email is in our system and it has not been confirmed yet,
          you will receive an email with instructions shortly.
        </p>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end


