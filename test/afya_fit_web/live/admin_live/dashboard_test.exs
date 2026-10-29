defmodule AfyaFitWeb.AdminLive.DashboardTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures
  import Phoenix.LiveViewTest

  setup do
    org = organization(%{name: "Njoroge Strength", plan_type: "free"})
    user(org, :org_admin)
    user(org, :trainer)
    user(org, :client)
    user(org, :client)
    %{org: org, platform_admin: user(organization(%{name: "Afya HQ"}), :admin)}
  end

  test "platform admins see every organisation with its counts", %{
    conn: conn,
    platform_admin: admin
  } do
    {:ok, view, _} = conn |> log_in(admin) |> live(~p"/admin/dashboard")

    assert has_element?(view, "#organizations", "Njoroge Strength")
    assert has_element?(view, "#organizations", "Free plan")
    assert has_element?(view, "#organizations", "2 trainers")
    assert has_element?(view, "#organizations", "Afya HQ")
  end

  test "the plan shown is the one the organisation pays for", %{
    conn: conn,
    org: org,
    platform_admin: admin
  } do
    subscription(org, %{plan_type: "enterprise"})

    {:ok, view, _} = conn |> log_in(admin) |> live(~p"/admin/dashboard")

    assert has_element?(view, "#organizations", "Enterprise plan")
  end

  test "everyone else gets the permission sign", %{conn: conn, org: org} do
    for role <- [:org_admin, :trainer, :client] do
      {:ok, view, _} = conn |> log_in(user(org, role)) |> live(~p"/admin/dashboard")
      assert has_element?(view, "#denied")
      refute has_element?(view, "#platform")
    end
  end
end
