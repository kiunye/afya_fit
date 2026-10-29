defmodule AfyaFitWeb.API.TaskControllerTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Tasks

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

  defp task!(org, trainer, client, attrs) do
    base = %{
      organization_id: org.id,
      trainer_id: trainer.id,
      client_id: client.id,
      title: "Task",
      task_type: "custom",
      status: "pending"
    }

    {:ok, task} = Tasks.create_task(Map.merge(base, attrs))
    task
  end

  defp ids(conn), do: for(t <- json_response(conn, 200)["data"], do: t["id"])

  defp body(client_id, extra),
    do: %{
      "task" =>
        Map.merge(
          %{"title" => "Check in", "task_type" => "checkin", "client_id" => client_id},
          extra
        )
    }

  describe "index" do
    test "trainer sees own and linked-client tasks; client sees only theirs", ctx do
      %{conn: conn, org: org, trainer: trainer, client: client, other: other, stranger: stranger} =
        ctx

      mine = task!(org, trainer, client, %{})
      linked_by_other = task!(org, other, client, %{})
      hidden = task!(org, other, stranger, %{})

      listed = conn |> authenticate(trainer) |> get(~p"/api/v1/tasks") |> ids()
      assert mine.id in listed and linked_by_other.id in listed
      refute hidden.id in listed

      assert Enum.sort(conn |> authenticate(client) |> get(~p"/api/v1/tasks") |> ids()) ==
               Enum.sort([mine.id, linked_by_other.id])
    end

    test "org admin sees the organization", %{
      conn: conn,
      org: org,
      other: other,
      stranger: stranger
    } do
      task = task!(org, other, stranger, %{})

      assert task.id in (conn
                         |> authenticate(user(org, :org_admin))
                         |> get(~p"/api/v1/tasks")
                         |> ids())
    end
  end

  describe "create" do
    test "trainer creates a task for a linked client", %{
      conn: conn,
      trainer: trainer,
      client: client
    } do
      assert conn
             |> authenticate(trainer)
             |> post(~p"/api/v1/tasks", body(client.id, %{}))
             |> json_response(201)
    end

    test "not for an unlinked client, and never as a client", ctx do
      %{conn: conn, trainer: trainer, client: client, stranger: stranger} = ctx

      assert conn
             |> authenticate(trainer)
             |> post(~p"/api/v1/tasks", body(stranger.id, %{}))
             |> json_response(403)

      assert conn
             |> authenticate(client)
             |> post(~p"/api/v1/tasks", body(client.id, %{}))
             |> json_response(403)
    end

    test "recurring tasks need the automation feature", %{conn: conn} do
      org = organization(%{plan_type: "free"})
      trainer = user(org, :trainer)
      client = user(org, :client)
      link(trainer, client)

      assert %{"error" => "upgrade_required", "feature" => "task_automation"} =
               conn
               |> authenticate(trainer)
               |> post(~p"/api/v1/tasks", body(client.id, %{"is_recurring" => true}))
               |> json_response(402)

      assert conn
             |> authenticate(trainer)
             |> post(~p"/api/v1/tasks", body(client.id, %{}))
             |> json_response(201)
    end
  end

  describe "show, update, delete, complete" do
    test "client reads and completes their task but cannot edit or delete it", ctx do
      %{conn: conn, org: org, trainer: trainer, client: client} = ctx
      task = task!(org, trainer, client, %{})
      conn = authenticate(conn, client)

      assert get(conn, ~p"/api/v1/tasks/#{task.id}") |> json_response(200)

      assert put(conn, ~p"/api/v1/tasks/#{task.id}", %{"task" => %{"title" => "X"}})
             |> json_response(403)

      assert delete(conn, ~p"/api/v1/tasks/#{task.id}") |> json_response(403)

      assert %{"data" => %{"status" => "completed"}} =
               post(conn, ~p"/api/v1/tasks/#{task.id}/complete") |> json_response(200)
    end

    test "a client cannot complete someone else's task", %{
      conn: conn,
      org: org,
      trainer: trainer,
      stranger: stranger,
      client: client
    } do
      task = task!(org, trainer, stranger, %{})

      assert conn
             |> authenticate(client)
             |> post(~p"/api/v1/tasks/#{task.id}/complete")
             |> json_response(403)
    end

    test "trainer edits and deletes; ownership fields are ignored", ctx do
      %{conn: conn, org: org, trainer: trainer, client: client, stranger: stranger} = ctx
      task = task!(org, trainer, client, %{})
      conn = authenticate(conn, trainer)

      body =
        put(conn, ~p"/api/v1/tasks/#{task.id}", %{
          "task" => %{"title" => "New", "client_id" => stranger.id}
        })
        |> json_response(200)

      assert body["data"]["title"] == "New"
      assert body["data"]["client_id"] == client.id

      assert delete(conn, ~p"/api/v1/tasks/#{task.id}") |> response(204)
    end

    test "another organization's task is not found", %{conn: conn, trainer: trainer} do
      foreign_org = organization()
      foreign_trainer = user(foreign_org, :trainer)
      task = task!(foreign_org, foreign_trainer, user(foreign_org, :client), %{})

      assert conn
             |> authenticate(trainer)
             |> get(~p"/api/v1/tasks/#{task.id}")
             |> json_response(404)
    end
  end

  describe "client_tasks and bulk" do
    test "client_tasks needs access to the client", %{
      conn: conn,
      trainer: trainer,
      client: client,
      stranger: stranger
    } do
      conn = authenticate(conn, trainer)
      assert get(conn, ~p"/api/v1/clients/#{client.id}/tasks") |> json_response(200)
      assert get(conn, ~p"/api/v1/clients/#{stranger.id}/tasks") |> json_response(403)
    end

    test "bulk skips clients the requester does not coach", %{
      conn: conn,
      trainer: trainer,
      client: client,
      stranger: stranger
    } do
      payload = %{"tasks" => [body(client.id, %{})["task"], body(stranger.id, %{})["task"]]}

      assert %{"created" => 1, "failed" => 1} =
               conn
               |> authenticate(trainer)
               |> post(~p"/api/v1/tasks/bulk", payload)
               |> json_response(200)
    end
  end
end
