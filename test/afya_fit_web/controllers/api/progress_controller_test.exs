defmodule AfyaFitWeb.API.ProgressControllerTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Tracking

  setup do
    org = organization()
    trainer = user(org, :trainer)
    client = user(org, :client)
    link(trainer, client)

    %{
      org: org,
      trainer: trainer,
      client: client,
      other: user(org, :trainer),
      stranger: user(org, :client)
    }
  end

  defp entry!(trainer, client, date \\ ~D[2026-01-01]) do
    {:ok, entry} =
      Tracking.create_progress_entry(%{
        client_id: client.id,
        trainer_id: trainer.id,
        entry_date: date,
        weight: 80
      })

    entry
  end

  defp params(date \\ "2026-02-01"),
    do: %{"progress_entry" => %{"entry_date" => date, "weight" => 79}}

  describe "index" do
    test "coach lists a linked client's entries", %{conn: conn, trainer: trainer, client: client} do
      entry = entry!(trainer, client)

      body =
        conn
        |> authenticate(trainer)
        |> get(~p"/api/v1/clients/#{client.id}/progress")
        |> json_response(200)

      assert [entry.id] == for(e <- body["data"], do: e["id"])
    end

    test "an unlinked client is forbidden, another organization's is not found", ctx do
      %{conn: conn, trainer: trainer, stranger: stranger} = ctx
      conn = authenticate(conn, trainer)
      assert get(conn, ~p"/api/v1/clients/#{stranger.id}/progress") |> json_response(403)

      foreign = user(organization(), :client)
      assert get(conn, ~p"/api/v1/clients/#{foreign.id}/progress") |> json_response(404)
    end

    test "a client reads their own entries and nobody else's", %{
      conn: conn,
      client: client,
      stranger: stranger
    } do
      conn = authenticate(conn, client)
      assert get(conn, ~p"/api/v1/clients/#{client.id}/progress") |> json_response(200)
      assert get(conn, ~p"/api/v1/clients/#{stranger.id}/progress") |> json_response(403)
    end
  end

  describe "create" do
    test "coach records an entry for a linked client", %{
      conn: conn,
      trainer: trainer,
      client: client
    } do
      body =
        conn
        |> authenticate(trainer)
        |> post(~p"/api/v1/clients/#{client.id}/progress", params())
        |> json_response(201)

      assert body["data"]["trainer_id"] == trainer.id
    end

    test "a client's entry is attributed to their trainer", %{
      conn: conn,
      trainer: trainer,
      client: client
    } do
      body =
        conn
        |> authenticate(client)
        |> post(~p"/api/v1/clients/#{client.id}/progress", params())
        |> json_response(201)

      assert body["data"]["trainer_id"] == trainer.id
    end

    test "an unlinked client cannot be recorded for", %{
      conn: conn,
      trainer: trainer,
      stranger: stranger
    } do
      assert conn
             |> authenticate(trainer)
             |> post(~p"/api/v1/clients/#{stranger.id}/progress", params())
             |> json_response(403)
    end
  end

  describe "show, update and delete" do
    test "coach and client can read; only the coach side edits and deletes", ctx do
      %{conn: conn, trainer: trainer, client: client, other: other, org: org} = ctx
      entry = entry!(trainer, client)
      update = %{"progress_entry" => %{"weight" => 78}}

      assert conn
             |> authenticate(client)
             |> get(~p"/api/v1/progress/#{entry.id}")
             |> json_response(200)

      assert conn
             |> authenticate(client)
             |> put(~p"/api/v1/progress/#{entry.id}", update)
             |> json_response(200)

      assert conn
             |> authenticate(client)
             |> delete(~p"/api/v1/progress/#{entry.id}")
             |> json_response(403)

      assert conn
             |> authenticate(other)
             |> get(~p"/api/v1/progress/#{entry.id}")
             |> json_response(403)

      assert conn
             |> authenticate(user(org, :org_admin))
             |> get(~p"/api/v1/progress/#{entry.id}")
             |> json_response(200)

      assert conn
             |> authenticate(trainer)
             |> delete(~p"/api/v1/progress/#{entry.id}")
             |> response(204)
    end

    test "ownership fields cannot be changed", %{
      conn: conn,
      trainer: trainer,
      client: client,
      stranger: stranger
    } do
      entry = entry!(trainer, client)
      update = %{"progress_entry" => %{"client_id" => stranger.id}}

      body =
        conn
        |> authenticate(trainer)
        |> put(~p"/api/v1/progress/#{entry.id}", update)
        |> json_response(200)

      assert body["data"]["client_id"] == client.id
    end

    test "entries of another organization are not found", %{conn: conn, trainer: trainer} do
      foreign_org = organization()
      foreign_client = user(foreign_org, :client)
      entry = entry!(user(foreign_org, :trainer), foreign_client)

      assert conn
             |> authenticate(trainer)
             |> get(~p"/api/v1/progress/#{entry.id}")
             |> json_response(404)
    end
  end

  describe "analytics" do
    test "available on pro, upgrade required on free", %{
      conn: conn,
      trainer: trainer,
      client: client
    } do
      entry!(trainer, client)

      assert conn
             |> authenticate(trainer)
             |> get(~p"/api/v1/clients/#{client.id}/progress/analytics")
             |> json_response(200)

      free = organization(%{plan_type: "free"})
      free_trainer = user(free, :trainer)
      free_client = user(free, :client)
      link(free_trainer, free_client)

      assert %{"error" => "upgrade_required", "feature" => "progress_analytics"} =
               conn
               |> authenticate(free_trainer)
               |> get(~p"/api/v1/clients/#{free_client.id}/progress/analytics")
               |> json_response(402)
    end
  end
end
