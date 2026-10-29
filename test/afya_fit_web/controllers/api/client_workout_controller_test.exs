defmodule AfyaFitWeb.API.ClientWorkoutControllerTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Workouts

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

  defp plan!(org, trainer, attrs) do
    {:ok, plan} =
      Workouts.create_workout_plan(
        Map.merge(%{name: "Plan", organization_id: org.id, trainer_id: trainer.id}, attrs)
      )

    plan
  end

  defp assignment!(trainer, client, plan) do
    {:ok, cw} =
      Workouts.create_client_workout(%{
        client_id: client.id,
        workout_plan_id: plan.id,
        assigned_by: trainer.id,
        assigned_date: ~D[2026-01-01],
        start_date: ~D[2026-01-01],
        status: "assigned"
      })

    cw
  end

  defp body(plan),
    do: %{
      "client_workout" => %{
        "workout_plan_id" => plan.id,
        "assigned_date" => "2026-01-01",
        "start_date" => "2026-01-01",
        "status" => "assigned"
      }
    }

  describe "index and create" do
    test "coach lists and assigns for a linked client", %{
      conn: conn,
      org: org,
      trainer: trainer,
      client: client
    } do
      plan = plan!(org, trainer, %{})
      conn = authenticate(conn, trainer)

      assert post(conn, ~p"/api/v1/clients/#{client.id}/workouts", body(plan))
             |> json_response(201)

      assert [_] =
               get(conn, ~p"/api/v1/clients/#{client.id}/workouts")
               |> json_response(200)
               |> Map.fetch!("data")
    end

    test "an unlinked client is forbidden", %{
      conn: conn,
      org: org,
      trainer: trainer,
      stranger: stranger
    } do
      plan = plan!(org, trainer, %{})
      conn = authenticate(conn, trainer)

      assert get(conn, ~p"/api/v1/clients/#{stranger.id}/workouts") |> json_response(403)

      assert post(conn, ~p"/api/v1/clients/#{stranger.id}/workouts", body(plan))
             |> json_response(403)
    end

    test "a client lists their own but cannot assign", %{
      conn: conn,
      org: org,
      trainer: trainer,
      client: client
    } do
      plan = plan!(org, trainer, %{})
      conn = authenticate(conn, client)

      assert get(conn, ~p"/api/v1/clients/#{client.id}/workouts") |> json_response(200)

      assert post(conn, ~p"/api/v1/clients/#{client.id}/workouts", body(plan))
             |> json_response(403)
    end

    test "plans the coach cannot read cannot be assigned", %{
      conn: conn,
      org: org,
      trainer: trainer,
      client: client,
      other: other
    } do
      private = plan!(org, other, %{})

      assert conn
             |> authenticate(trainer)
             |> post(~p"/api/v1/clients/#{client.id}/workouts", body(private))
             |> json_response(403)

      foreign_org = organization()
      foreign = plan!(foreign_org, user(foreign_org, :trainer), %{is_public: true})

      assert conn
             |> authenticate(trainer)
             |> post(~p"/api/v1/clients/#{client.id}/workouts", body(foreign))
             |> json_response(404)
    end

    test "a cancelled subscription blocks assigning", %{
      conn: conn,
      org: org,
      trainer: trainer,
      client: client
    } do
      plan = plan!(org, trainer, %{})
      subscription(org, %{status: "cancelled"})

      assert %{"error" => "subscription_inactive"} =
               conn
               |> authenticate(trainer)
               |> post(~p"/api/v1/clients/#{client.id}/workouts", body(plan))
               |> json_response(402)
    end
  end

  describe "update, delete and complete" do
    test "coach updates and deletes; ownership fields are ignored", ctx do
      %{conn: conn, org: org, trainer: trainer, client: client, stranger: stranger} = ctx
      cw = assignment!(trainer, client, plan!(org, trainer, %{}))
      conn = authenticate(conn, trainer)

      body =
        put(conn, ~p"/api/v1/client-workouts/#{cw.id}", %{
          "client_workout" => %{"notes" => "n", "client_id" => stranger.id}
        })
        |> json_response(200)

      assert body["data"]["notes"] == "n"
      assert body["data"]["client_id"] == client.id
      assert delete(conn, ~p"/api/v1/client-workouts/#{cw.id}") |> response(204)
    end

    test "the client completes their own but cannot edit or delete", %{
      conn: conn,
      org: org,
      trainer: trainer,
      client: client
    } do
      cw = assignment!(trainer, client, plan!(org, trainer, %{}))
      conn = authenticate(conn, client)

      assert %{"data" => %{"status" => "completed"}} =
               post(conn, ~p"/api/v1/client-workouts/#{cw.id}/complete") |> json_response(200)

      assert put(conn, ~p"/api/v1/client-workouts/#{cw.id}", %{
               "client_workout" => %{"notes" => "x"}
             })
             |> json_response(403)

      assert delete(conn, ~p"/api/v1/client-workouts/#{cw.id}") |> json_response(403)
    end

    test "another client cannot complete it, another trainer cannot touch it", %{
      conn: conn,
      org: org,
      trainer: trainer,
      client: client,
      stranger: stranger,
      other: other
    } do
      cw = assignment!(trainer, client, plan!(org, trainer, %{}))

      assert conn
             |> authenticate(stranger)
             |> post(~p"/api/v1/client-workouts/#{cw.id}/complete")
             |> json_response(403)

      assert conn
             |> authenticate(other)
             |> delete(~p"/api/v1/client-workouts/#{cw.id}")
             |> json_response(403)
    end

    test "another organization's assignment is not found", %{conn: conn, trainer: trainer} do
      foreign_org = organization()
      foreign_trainer = user(foreign_org, :trainer)
      foreign_client = user(foreign_org, :client)
      cw = assignment!(foreign_trainer, foreign_client, plan!(foreign_org, foreign_trainer, %{}))

      assert conn
             |> authenticate(trainer)
             |> post(~p"/api/v1/client-workouts/#{cw.id}/complete")
             |> json_response(404)
    end
  end
end
