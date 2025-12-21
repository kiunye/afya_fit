defmodule AfyaFitWeb.PageLive do
  use AfyaFitWeb, :live_view

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="text-center">
        <h1 class="text-4xl font-bold">Welcome to Afya Fit</h1>
        <p class="mt-4 text-lg">Your fitness management platform</p>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
