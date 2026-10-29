defmodule AfyaFitWeb.API.AccessPayloadTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Accounts.User

  defp me(conn, user),
    do: conn |> authenticate(user) |> get(~p"/api/v1/auth/me") |> json_response(200)

  describe "GET /auth/me" do
    test "a pro trainer gets role permissions, entitlements and the organisation" do
      org = organization(%{name: "Njoroge Strength", plan_type: "pro"})
      owner = user(org, :org_admin, %{first_name: "Wanjiru", last_name: "Njoroge"})
      trainer = user(org, :trainer)

      body = me(build_conn(), trainer)

      assert body["data"]["role"] == "trainer"
      assert body["data"]["account_role"] == "trainer"

      access = body["access"]
      assert "create" in access["permissions"]["client"]
      assert "analytics" in access["permissions"]["progress_entry"]
      refute Map.has_key?(access["permissions"], "subscription")

      assert %{"tier" => "pro", "client_limit" => 25, "client_count" => 0} =
               access["entitlements"]

      assert Enum.all?(Map.values(access["entitlements"]["features"]))
      assert %{"state" => "active", "reason" => nil} = access["entitlements"]["billing"]

      assert access["organization"] == %{
               "name" => "Njoroge Strength",
               "owner_name" => "Wanjiru Njoroge"
             }

      assert owner
    end

    test "a free organisation shows the limit and the closed features" do
      org = organization(%{plan_type: "free"})
      trainer = user(org, :trainer)
      for _ <- 1..2, do: link(trainer, user(org, :client))

      entitlements = me(build_conn(), trainer)["access"]["entitlements"]

      assert %{"tier" => "free", "client_limit" => 3, "client_count" => 2} = entitlements

      assert %{"nutrition_plans" => false, "calendar" => false, "progress_analytics" => false} =
               entitlements["features"]
    end

    test "enterprise has no client limit" do
      org = organization(%{plan_type: "enterprise"})

      assert me(build_conn(), user(org, :trainer))["access"]["entitlements"]["client_limit"] ==
               nil
    end

    test "the plan comes from the subscription" do
      org = organization(%{plan_type: "free"})
      subscription(org, %{plan_type: "pro"})

      assert me(build_conn(), user(org, :trainer))["access"]["entitlements"]["tier"] == "pro"
    end

    test "a lapsed account reports the billing state and reason" do
      org = organization()
      subscription(org, %{status: "cancelled"})

      billing = me(build_conn(), user(org, :trainer))["access"]["entitlements"]["billing"]

      assert %{"state" => "read_only", "reason" => "cancelled"} = billing
    end

    test "a client sees only what a client may do" do
      org = organization()
      permissions = me(build_conn(), user(org, :client))["access"]["permissions"]

      assert "complete" in permissions["client_workout"]
      assert "create" in permissions["progress_entry"]
      refute Map.has_key?(permissions, "workout_plan")
      refute Map.has_key?(permissions, "subscription")
    end

    test "an organisation admin keeps role trainer for older apps and exposes the real role" do
      org = organization()
      admin = user(org, :org_admin)

      body = me(build_conn(), admin)

      assert User.legacy_role(admin) == "trainer"
      assert body["data"]["role"] == "trainer"
      assert body["data"]["account_role"] == "org_admin"
      assert "manage" in body["access"]["permissions"]["subscription"]
    end
  end

  describe "login and registration" do
    test "login returns the same access payload", %{conn: conn} do
      org = organization()
      password = "a-long-enough-password"

      user =
        user(org, :trainer, %{
          password_hash: Bcrypt.hash_pwd_salt(password),
          email: "login@example.com"
        })

      body =
        conn
        |> post(~p"/api/v1/auth/login", %{
          "user" => %{"email" => user.email, "password" => password}
        })
        |> json_response(200)

      assert body["token"]
      assert body["access"]["entitlements"]["tier"] == "pro"
      assert "create" in body["access"]["permissions"]["client"]
    end

    test "registering a trainer returns a free-plan payload", %{conn: conn} do
      n = System.unique_integer([:positive])

      body =
        conn
        |> post(~p"/api/v1/auth/register", %{
          "user" => %{
            "email" => "new#{n}@example.com",
            "password" => "a-long-enough-password",
            "first_name" => "New",
            "last_name" => "Trainer",
            "role" => "trainer",
            "organization_name" => "Gym #{n}",
            "organization_subdomain" => "gym-#{n}"
          }
        })
        |> json_response(201)

      assert body["access"]["entitlements"]["tier"] == "free"
      assert body["access"]["entitlements"]["client_limit"] == 3
    end
  end
end
