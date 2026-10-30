defmodule AfyaFitWeb.CacheBodyReader do
  @moduledoc """
  Keeps the raw request body of webhook requests in `conn.assigns.raw_body`.
  A webhook's signature covers the exact bytes the provider sent, and by the
  time the JSON parser is done those bytes are gone.

  Only paths under `/webhooks` are kept, so ordinary requests pay nothing.
  """

  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {status, body, conn} when status in [:ok, :more] ->
        {status, body, remember(conn, body)}

      other ->
        other
    end
  end

  defp remember(%Plug.Conn{path_info: ["webhooks" | _]} = conn, body) do
    Plug.Conn.assign(conn, :raw_body, (conn.assigns[:raw_body] || "") <> body)
  end

  defp remember(conn, _body), do: conn
end
