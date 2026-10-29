defmodule AfyaFitWeb.API.WorkoutPlanControllerTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Workouts

  setup do
    org = organization()
    %{org: org, trainer: user(org, :trainer), other: user(org, :trainer), client: user(org, :client)}
  end

  defp plan!(org, trainer, attrs \\ %{}) do
    {:ok, plan} =
      Workouts.create_workout_plan(
        Map.merge(
          %{
            name: "Plan",
            organization_id: org.id,
            trainer_id: trainer.id
          },
          attrs
        )
      )

    plan
  end

  defp ids(conn), do: for(p <- json_response(conn, 200)["data"], do: p["id"])

  describe "authentication" do
    test "requires a token", %{conn: conn} do
      assert conn |> get(~p"/api/v1/workout-plans") |> json_response(401)
    end
  end

  describe "index" do
    test "lists own, public and template plans, never private plans or other organizations'", %{
      conn: conn,
      org: org,
      trainer: trainer,
      other: other
    } do
      mine = plan!(org, trainer)
      public = plan!(org, other, %{is_public: true})
      template = plan!(org, other, %{is_template: true})
      private = plan!(org, other)
      foreign_org = organization()
      foreign = plan!(foreign_org, user(foreign_org, :trainer), %{is_public: true})

      listed = conn |> authenticate(trainer) |> get(~p"/api/v1/workout-plans") |> ids()

      assert mine.id in listed
      assert public.id in listed
      assert template.id in listed
      refute private.id in listed
      refute foreign.id in listed
    end

    test "org admin sees every plan in the organization", %{conn: conn, org: org, other: other} do
      admin = user(org, :org_admin)
      private = plan!(org, other)

      assert private.id in (conn |> authenticate(admin) |> get(~p"/api/v1/workout-plans") |> ids())
    end

    test "clients are forbidden", %{conn: conn, client: client} do
      assert conn |> authenticate(client) |> get(~p"/api/v1/workout-plans") |> json_response(403)
    end
  end

  describe "show" do
    test "owner and public plans are readable", %{conn: conn, org: org, trainer: trainer, other: other} do
      public = plan!(org, other, %{is_public: true})
      conn = authenticate(conn, trainer)
      assert get(conn, ~p"/api/v1/workout-plans/#{public.id}") |> json_response(200)
    end

    test "another trainer's private plan is forbidden", %{conn: conn, org: org, trainer: trainer, other: other} do
      private = plan!(org, other)

      assert conn
             |> authenticate(trainer)
             |> get(~p"/api/v1/workout-plans/#{private.id}")
             |> json_response(403)
    end

    test "a plan from another organization is not found", %{conn: conn, trainer: trainer} do
      foreign_org = organization()
      foreign = plan!(foreign_org, user(foreign_org, :trainer), %{is_public: true})

      assert conn
             |> authenticate(trainer)
             |> get(~p"/api/v1/workout-plans/#{foreign.id}")
             |> json_response(404)
    end
  end

  describe "create" do
    test "a trainer creates a plan they own", %{conn: conn, trainer: trainer} do
      conn =
        conn
        |> authenticate(trainer)
        |> post(~p"/api/v1/workout-plans", %{"workout_plan" => %{"name" => "Strength"}})

      assert %{"data" => %{"trainer_id" => trainer_id}} = json_response(conn, 201)
      assert trainer_id == trainer.id
    end

    test "clients are forbidden", %{conn: conn, client: client} do
      conn =
        conn
        |> authenticate(client)
        |> post(~p"/api/v1/workout-plans", %{"workout_plan" => %{"name" => "Nope"}})

      assert json_response(conn, 403)
    end

    test "a cancelled subscription makes the account read-only", %{conn: conn, org: org, trainer: trainer} do
      subscription(org, %{status: "cancelled"})

      conn =
        conn
        |> authenticate(trainer)
        |> post(~p"/api/v1/workout-plans", %{"workout_plan" => %{"name" => "Blocked"}})

      assert %{"error" => "subscription_inactive"} = json_response(conn, 402)
    end
  end

  describe "update and delete" do
    test "owner can update and delete", %{conn: conn, org: org, trainer: trainer} do
      plan = plan!(org, trainer)
      conn = authenticate(conn, trainer)

      assert %{"data" => %{"name" => "Renamed"}} =
               conn
               |> put(~p"/api/v1/workout-plans/#{plan.id}", %{"workout_plan" => %{"name" => "Renamed"}})
               |> json_response(200)

      assert conn |> delete(~p"/api/v1/workout-plans/#{plan.id}") |> response(204)
    end

    test "another trainer cannot touch a public plan", %{conn: conn, org: org, trainer: trainer, other: other} do
      plan = plan!(org, other, %{is_public: true})
      conn = authenticate(conn, trainer)

      assert conn
             |> put(~p"/api/v1/workout-plans/#{plan.id}", %{"workout_plan" => %{"name" => "X"}})
             |> json_response(403)

      assert conn |> delete(~p"/api/v1/workout-plans/#{plan.id}") |> json_response(403)
    end

    test "org admin can edit any plan in the organization", %{conn: conn, org: org, other: other} do
      plan = plan!(org, other)
      admin = user(org, :org_admin)

      assert conn
             |> authenticate(admin)
             |> put(~p"/api/v1/workout-plans/#{plan.id}", %{"workout_plan" => %{"name" => "Edited"}})
             |> json_response(200)
    end

    test "platform admin cannot edit plans", %{conn: conn, org: org, trainer: trainer} do
      plan = plan!(org, trainer)
      platform_admin = user(org, :admin)

      assert conn
             |> authenticate(platform_admin)
             |> put(~p"/api/v1/workout-plans/#{plan.id}", %{"workout_plan" => %{"name" => "X"}})
             |> json_response(403)
    end
  end

  describe "duplicate" do
    test "copies a readable plan into the requester's ownership", %{conn: conn, org: org, trainer: trainer, other: other} do
      plan = plan!(org, other, %{is_public: true})

      conn = conn |> authenticate(trainer) |> post(~p"/api/v1/workout-plans/#{plan.id}/duplicate")

      assert %{"data" => %{"trainer_id" => trainer_id, "name" => "Plan (Copy)"}} = json_response(conn, 201)
      assert trainer_id == trainer.id
    end

    test "a private plan of another trainer cannot be copied", %{conn: conn, org: org, trainer: trainer, other: other} do
      plan = plan!(org, other)

      assert conn
             |> authenticate(trainer)
             |> post(~p"/api/v1/workout-plans/#{plan.id}/duplicate")
             |> json_response(403)
    end
  end

  describe "templates" do
    test "lists the organization's templates only", %{conn: conn, org: org, trainer: trainer, other: other} do
      template = plan!(org, other, %{is_template: true})
      plain = plan!(org, other)
      foreign_org = organization()
      foreign = plan!(foreign_org, user(foreign_org, :trainer), %{is_template: true})

      listed = conn |> authenticate(trainer) |> get(~p"/api/v1/workout-plans/templates") |> ids()

      assert template.id in listed
      refute plain.id in listed
      refute foreign.id in listed
    end
  end
end
