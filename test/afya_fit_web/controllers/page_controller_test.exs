defmodule AfyaFitWeb.PageControllerTest do
  use AfyaFitWeb.ConnCase

  test "GET / shows the landing page to visitors", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert html = html_response(conn, 200)
    assert html =~ "Afya Fit"
    assert html =~ "Sign in"
  end
end
