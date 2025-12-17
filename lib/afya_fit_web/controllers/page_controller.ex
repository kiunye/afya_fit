defmodule AfyaFitWeb.PageController do
  use AfyaFitWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
