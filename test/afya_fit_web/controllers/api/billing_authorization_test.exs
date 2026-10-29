defmodule AfyaFitWeb.API.BillingAuthorizationTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures

  setup do
    org = organization()
    subscription(org)

    %{
      org: org,
      org_admin: user(org, :org_admin),
      trainer: user(org, :trainer),
      client: user(org, :client),
      platform_admin: user(org, :admin)
    }
  end

  describe "organization subscription" do
    test "only organization admins and platform admins can read it", ctx do
      %{
        conn: conn,
        org_admin: org_admin,
        platform_admin: platform_admin,
        trainer: trainer,
        client: client
      } = ctx

      assert conn
             |> authenticate(org_admin)
             |> get(~p"/api/v1/subscriptions")
             |> json_response(200)

      assert conn
             |> authenticate(platform_admin)
             |> get(~p"/api/v1/subscriptions")
             |> json_response(200)

      assert conn |> authenticate(trainer) |> get(~p"/api/v1/subscriptions") |> json_response(403)
      assert conn |> authenticate(client) |> get(~p"/api/v1/subscriptions") |> json_response(403)
    end

    test "trainers and clients cannot change, cancel or list invoices", %{
      conn: conn,
      trainer: trainer,
      client: client
    } do
      for user <- [trainer, client] do
        conn = authenticate(conn, user)

        assert put(conn, ~p"/api/v1/subscriptions", %{
                 "subscription" => %{"plan_type" => "enterprise"}
               })
               |> json_response(403)

        assert delete(conn, ~p"/api/v1/subscriptions") |> json_response(403)
        assert get(conn, ~p"/api/v1/subscriptions/invoices") |> json_response(403)

        assert post(conn, ~p"/api/v1/subscriptions", %{"subscription" => %{}})
               |> json_response(403)
      end
    end

    test "an organization admin can still manage billing while read-only", %{
      conn: conn,
      org: org,
      org_admin: org_admin
    } do
      AfyaFit.Repo.get_by!(AfyaFit.Billing.Subscription, organization_id: org.id)
      |> Ecto.Changeset.change(status: "expired")
      |> AfyaFit.Repo.update!()

      assert conn
             |> authenticate(org_admin)
             |> get(~p"/api/v1/subscriptions/invoices")
             |> json_response(200)
    end
  end

  describe "payments" do
    test "trainers and clients cannot start a payment", %{
      conn: conn,
      trainer: trainer,
      client: client
    } do
      for user <- [trainer, client] do
        assert conn
               |> authenticate(user)
               |> post(~p"/api/v1/payments/initialize", %{"payment" => %{"amount" => 100}})
               |> json_response(403)
      end
    end
  end

  describe "admin endpoints" do
    test "only platform admins", ctx do
      %{conn: conn, org_admin: org_admin, trainer: trainer, platform_admin: platform_admin} = ctx

      for path <- [~p"/api/v1/admin/trainers", ~p"/api/v1/admin/clients"] do
        assert conn |> authenticate(platform_admin) |> get(path) |> json_response(200)
        assert conn |> authenticate(org_admin) |> get(path) |> json_response(403)
        assert conn |> authenticate(trainer) |> get(path) |> json_response(403)
      end
    end
  end
end
