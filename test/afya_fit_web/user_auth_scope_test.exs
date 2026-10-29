defmodule AfyaFitWeb.UserAuthScopeTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Authorization.Scope

  setup do
    org = organization()
    %{org: org, trainer: user(org, :trainer)}
  end

  test "a logged-in browser request carries the full authorization scope", %{
    conn: conn,
    trainer: trainer
  } do
    conn = conn |> log_in(trainer) |> get(~p"/")

    assert %Scope{user: %{id: id}, tier: "pro"} = conn.assigns.current_scope
    assert id == trainer.id
  end

  test "a visitor gets a bare scope with no user", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert %{user: nil} = conn.assigns.current_scope
  end
end
