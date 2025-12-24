defmodule AfyaFitWeb.PageControllerTest do
  use AfyaFitWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Welcome to Afya Fit - Your fitness management platform"
  end
end
