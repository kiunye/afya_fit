defmodule AfyaFitWeb.ScopedAction do
  @moduledoc """
  Runs a controller action inside the requester's tenant context for row-level
  security (see `AfyaFit.RLS`).

  A record that is missing is answered with the standard 404. That is also what
  RLS produces for another tenant's record: it does not exist for the request.
  """

  import Plug.Conn, only: [put_status: 2]
  import Phoenix.Controller, only: [action_name: 1, put_view: 2, render: 2]

  def run(conn, controller) do
    AfyaFit.RLS.with_scope(conn.assigns[:current_scope], fn ->
      apply(controller, action_name(conn), [conn, conn.params])
    end)
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> put_view(html: AfyaFitWeb.ErrorHTML, json: AfyaFitWeb.ErrorJSON)
      |> render(:"404")
  end
end
