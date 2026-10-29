defmodule AfyaFitWeb.API.NutritionPlanControllerTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Nutrition

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

  defp plan!(org, trainer, attrs \\ %{}) do
    # The table requires a client and a start date on every plan
    base = %{
      name: "Plan",
      organization_id: org.id,
      trainer_id: trainer.id,
      client_id: Map.get_lazy(attrs, :client_id, fn -> user(org, :client).id end),
      start_date: ~D[2026-01-01]
    }

    {:ok, plan} = Nutrition.create_nutrition_plan(Map.merge(base, attrs))

    plan
  end

  defp ids(conn), do: for(p <- json_response(conn, 200)["data"], do: p["id"])

  describe "index" do
    test "trainer sees own, linked-client and template plans only", ctx do
      %{conn: conn, org: org, trainer: trainer, client: client, other: other, stranger: stranger} =
        ctx

      own = plan!(org, trainer)
      for_client = plan!(org, other, %{client_id: client.id})
      template = plan!(org, other, %{is_template: true})
      hidden = plan!(org, other, %{client_id: stranger.id})

      listed = conn |> authenticate(trainer) |> get(~p"/api/v1/nutrition-plans") |> ids()

      assert Enum.all?([own.id, for_client.id, template.id], &(&1 in listed))
      refute hidden.id in listed
    end

    test "a client sees only plans assigned to them", %{
      conn: conn,
      org: org,
      trainer: trainer,
      client: client,
      stranger: stranger
    } do
      mine = plan!(org, trainer, %{client_id: client.id})
      theirs = plan!(org, trainer, %{client_id: stranger.id})

      listed = conn |> authenticate(client) |> get(~p"/api/v1/nutrition-plans") |> ids()

      assert listed == [mine.id]
      refute theirs.id in listed
    end

    test "org admin sees the whole organization", %{
      conn: conn,
      org: org,
      other: other,
      stranger: stranger
    } do
      plan = plan!(org, other, %{client_id: stranger.id})

      assert plan.id in (conn
                         |> authenticate(user(org, :org_admin))
                         |> get(~p"/api/v1/nutrition-plans")
                         |> ids())
    end
  end

  describe "show" do
    test "client reads own plan, not others'", %{
      conn: conn,
      org: org,
      trainer: trainer,
      client: client,
      stranger: stranger
    } do
      mine = plan!(org, trainer, %{client_id: client.id})
      theirs = plan!(org, trainer, %{client_id: stranger.id})
      conn = authenticate(conn, client)

      assert get(conn, ~p"/api/v1/nutrition-plans/#{mine.id}") |> json_response(200)
      assert get(conn, ~p"/api/v1/nutrition-plans/#{theirs.id}") |> json_response(403)
    end

    test "other organization is not found", %{conn: conn, trainer: trainer} do
      foreign_org = organization()
      plan = plan!(foreign_org, user(foreign_org, :trainer))

      assert conn
             |> authenticate(trainer)
             |> get(~p"/api/v1/nutrition-plans/#{plan.id}")
             |> json_response(404)
    end
  end

  describe "create" do
    test "trainer assigns a plan to a linked client", %{
      conn: conn,
      trainer: trainer,
      client: client
    } do
      params = %{
        "nutrition_plan" => %{
          "name" => "Cut",
          "client_id" => client.id,
          "start_date" => "2026-01-01"
        }
      }

      assert conn
             |> authenticate(trainer)
             |> post(~p"/api/v1/nutrition-plans", params)
             |> json_response(201)
    end

    test "trainer cannot assign to an unlinked client", %{
      conn: conn,
      trainer: trainer,
      stranger: stranger
    } do
      params = %{"nutrition_plan" => %{"name" => "Cut", "client_id" => stranger.id}}

      assert conn
             |> authenticate(trainer)
             |> post(~p"/api/v1/nutrition-plans", params)
             |> json_response(403)
    end

    test "the free tier needs an upgrade", %{conn: conn} do
      org = organization(%{plan_type: "free"})
      trainer = user(org, :trainer)
      params = %{"nutrition_plan" => %{"name" => "Cut"}}

      assert %{
               "error" => "upgrade_required",
               "feature" => "nutrition_plans",
               "required_tier" => "pro"
             } =
               conn
               |> authenticate(trainer)
               |> post(~p"/api/v1/nutrition-plans", params)
               |> json_response(402)
    end

    test "clients are forbidden", %{conn: conn, client: client} do
      params = %{"nutrition_plan" => %{"name" => "Mine"}}

      assert conn
             |> authenticate(client)
             |> post(~p"/api/v1/nutrition-plans", params)
             |> json_response(403)
    end
  end

  describe "update and delete" do
    test "owner only; org admin too; client never", %{
      conn: conn,
      org: org,
      trainer: trainer,
      client: client,
      other: other
    } do
      plan = plan!(org, trainer, %{client_id: client.id})
      params = %{"nutrition_plan" => %{"name" => "Renamed"}}

      assert conn
             |> authenticate(trainer)
             |> put(~p"/api/v1/nutrition-plans/#{plan.id}", params)
             |> json_response(200)

      assert conn
             |> authenticate(user(org, :org_admin))
             |> put(~p"/api/v1/nutrition-plans/#{plan.id}", params)
             |> json_response(200)

      assert conn
             |> authenticate(other)
             |> put(~p"/api/v1/nutrition-plans/#{plan.id}", params)
             |> json_response(403)

      assert conn
             |> authenticate(client)
             |> put(~p"/api/v1/nutrition-plans/#{plan.id}", params)
             |> json_response(403)

      assert conn
             |> authenticate(trainer)
             |> delete(~p"/api/v1/nutrition-plans/#{plan.id}")
             |> response(204)
    end
  end

  describe "client_nutrition" do
    test "trainer lists a linked client's plans; unlinked client is forbidden", ctx do
      %{conn: conn, org: org, trainer: trainer, client: client, stranger: stranger} = ctx
      plan = plan!(org, trainer, %{client_id: client.id})

      conn = authenticate(conn, trainer)
      assert plan.id in (get(conn, ~p"/api/v1/clients/#{client.id}/nutrition") |> ids())
      assert get(conn, ~p"/api/v1/clients/#{stranger.id}/nutrition") |> json_response(403)
    end
  end
end
