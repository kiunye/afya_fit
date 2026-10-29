defmodule AfyaFitWeb.API.MeControllerTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures

  setup do
    org = organization()
    trainer = user(org, :trainer)
    client = user(org, :client)
    link(trainer, client)
    %{org: org, trainer: trainer, client: client}
  end

  @params %{"progress_entry" => %{"entry_date" => "2026-02-01", "weight" => 70}}

  test "a client records their own progress, attributed to their trainer", %{
    conn: conn,
    trainer: trainer,
    client: client
  } do
    body =
      conn |> authenticate(client) |> post(~p"/api/v1/me/progress", @params) |> json_response(201)

    assert body["data"]["client_id"] == client.id
    assert body["data"]["trainer_id"] == trainer.id
  end

  test "a cancelled coach subscription does not stop clients recording progress", %{
    conn: conn,
    org: org,
    client: client
  } do
    subscription(org, %{status: "cancelled"})

    assert conn
           |> authenticate(client)
           |> post(~p"/api/v1/me/progress", @params)
           |> json_response(201)
  end

  test "a client without a subscription gets a 404", %{conn: conn, client: client} do
    assert conn |> authenticate(client) |> get(~p"/api/v1/me/subscription") |> json_response(404)
  end

  test "coaches have no client subscription to read or edit", %{conn: conn, trainer: trainer} do
    conn = authenticate(conn, trainer)

    assert get(conn, ~p"/api/v1/me/subscription") |> json_response(403)

    assert put(conn, ~p"/api/v1/me/subscription/reminders", %{"reminder_preferences" => %{}})
           |> json_response(403)
  end
end
