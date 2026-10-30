defmodule AfyaFitWeb.AdminLive.PlatformPagesTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures
  import Phoenix.LiveViewTest

  alias AfyaFit.Organizations.Organization
  alias AfyaFit.Repo

  setup do
    org = organization(%{name: "Njoroge Strength", plan_type: "free"})
    owner = user(org, :org_admin, %{first_name: "Wanjiru", last_name: "Njoroge"})
    user(org, :trainer, %{first_name: "Brian", last_name: "Kariuki", email: "brian@example.com"})

    %{
      org: org,
      owner: owner,
      admin: user(organization(%{name: "Afya HQ"}), :admin)
    }
  end

  describe "the organisation page" do
    test "shows the plan, team and a way in from the list", ctx do
      %{conn: conn, org: org, admin: admin} = ctx
      {:ok, view, _} = conn |> log_in(admin) |> live(~p"/admin/dashboard")

      view |> element("#organizations a[href='/admin/organizations/#{org.id}']") |> render_click()
      assert_redirect(view, ~p"/admin/organizations/#{org.id}")

      {:ok, view, _} = conn |> log_in(admin) |> live(~p"/admin/organizations/#{org.id}")

      assert has_element?(view, "#plan", "Free plan")
      assert has_element?(view, "#organization", "Wanjiru Njoroge")
      assert has_element?(view, "#organization", "Brian Kariuki")
    end

    test "suspending asks first, then makes the organisation read-only", ctx do
      %{conn: conn, org: org, admin: admin} = ctx
      {:ok, view, _} = conn |> log_in(admin) |> live(~p"/admin/organizations/#{org.id}")

      view |> element("#ask-suspend") |> render_click()
      assert has_element?(view, "#suspend-confirm", "Suspend Njoroge Strength?")

      view |> element("#keep-active") |> render_click()
      refute has_element?(view, "#suspend-confirm")
      assert Repo.get!(Organization, org.id).status == "active"

      view |> element("#ask-suspend") |> render_click()
      view |> element("#confirm-suspend") |> render_click()

      assert render(view) =~ "Suspended."
      assert Repo.get!(Organization, org.id).status == "suspended"
      assert has_element?(view, "#reactivate")
    end

    test "reactivating puts it back", %{conn: conn, org: org, admin: admin} do
      Repo.update!(Organization.changeset(org, %{status: "suspended"}))
      {:ok, view, _} = conn |> log_in(admin) |> live(~p"/admin/organizations/#{org.id}")

      view |> element("#reactivate") |> render_click()

      assert Repo.get!(Organization, org.id).status == "active"
    end

    test "granting a plan updates the organisation and shows in its activity", ctx do
      %{conn: conn, org: org, admin: admin} = ctx
      {:ok, view, _} = conn |> log_in(admin) |> live(~p"/admin/organizations/#{org.id}")

      view
      |> form("#grant-form", grant: %{plan: "pro", days: "90"})
      |> render_submit()

      assert render(view) =~ "Pro granted for 90 days."
      assert has_element?(view, "#plan", "Pro plan")
      assert has_element?(view, "#activity", "platform.grant_plan")
    end

    test "tampered grant values are refused", %{conn: conn, org: org, admin: admin} do
      {:ok, view, _} = conn |> log_in(admin) |> live(~p"/admin/organizations/#{org.id}")

      render_hook(view, "grant", %{"grant" => %{"plan" => "gold", "days" => "7"}})

      assert has_element?(view, "#flash-error")
      assert has_element?(view, "#plan", "Free plan")
    end

    test "an unknown organisation gets the not-found sign", %{conn: conn, admin: admin} do
      {:ok, view, _} =
        conn |> log_in(admin) |> live(~p"/admin/organizations/#{Ecto.UUID.generate()}")

      assert has_element?(view, "#denied")
    end

    test "owners and trainers cannot open it", %{conn: conn, org: org, owner: owner} do
      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/admin/organizations/#{org.id}")

      assert has_element?(view, "#denied")
      refute has_element?(view, "#organization")
    end
  end

  describe "subscriptions" do
    setup %{org: org} do
      subscription(org, %{status: "past_due", plan_type: "pro"})

      subscription(organization(%{name: "Cancelling Gym"}), %{
        status: "cancelled",
        cancel_at_period_end: true
      })

      :ok
    end

    test "lists them with a state filter in the URL", %{conn: conn, admin: admin} do
      {:ok, view, _} = conn |> log_in(admin) |> live(~p"/admin/subscriptions")
      assert has_element?(view, "#subscriptions", "Njoroge Strength")
      assert has_element?(view, "#subscriptions", "Cancelling Gym")

      {:ok, view, _} = conn |> log_in(admin) |> live(~p"/admin/subscriptions?status=past_due")
      assert has_element?(view, "#subscriptions", "Njoroge Strength")
      refute has_element?(view, "#subscriptions", "Cancelling Gym")
    end

    test "shows what the active plans bring in", %{conn: conn, admin: admin} do
      AfyaFit.Repo.update_all(AfyaFit.Billing.Subscription, set: [status: "active"])

      {:ok, view, _} = conn |> log_in(admin) |> live(~p"/admin/subscriptions")

      income = AfyaFit.Billing.Plans.format(AfyaFit.Platform.monthly_income())
      assert income != "KES 0"
      assert has_element?(view, "#subscriptions-page", "Expected each month")
      assert has_element?(view, "#subscriptions-page", income)
    end

    test "everyone else gets the permission sign", %{conn: conn, owner: owner} do
      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/admin/subscriptions")
      assert has_element?(view, "#denied")
    end
  end

  describe "users" do
    test "searching finds people across organisations", %{conn: conn, admin: admin} do
      {:ok, view, _} = conn |> log_in(admin) |> live(~p"/admin/users")
      assert has_element?(view, "#users-empty", "Type to search.")

      view |> form("#search-form", search: %{q: "brian"}) |> render_change()

      assert_patch(view, ~p"/admin/users?q=brian")
      assert has_element?(view, "#users", "brian@example.com")
      assert has_element?(view, "#users", "Njoroge Strength")
    end

    test "no match says so", %{conn: conn, admin: admin} do
      {:ok, view, _} = conn |> log_in(admin) |> live(~p"/admin/users?q=zzzz")
      assert has_element?(view, "#users-empty", "No one matches.")
    end

    test "everyone else gets the permission sign", %{conn: conn, owner: owner} do
      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/admin/users")
      assert has_element?(view, "#denied")
    end
  end
end
