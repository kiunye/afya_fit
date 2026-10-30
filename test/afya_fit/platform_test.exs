defmodule AfyaFit.PlatformTest do
  use AfyaFit.DataCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Billing.Subscription
  alias AfyaFit.Organizations.Organization
  alias AfyaFit.Platform
  alias AfyaFit.Repo
  alias AfyaFit.Shared.ActivityLog

  setup do
    org = organization(%{name: "Njoroge Strength", plan_type: "free"})
    owner = user(org, :org_admin)

    %{
      org: org,
      owner: owner,
      admin: user(organization(%{name: "Afya HQ"}), :admin) |> Scope.load()
    }
  end

  describe "get_organization/1" do
    test "finds an organization", %{org: org} do
      assert {:ok, %Organization{id: id}} = Platform.get_organization(org.id)
      assert id == org.id
    end

    test "unknown, malformed and deleted ids are not found", %{org: org} do
      Repo.update_all(Organization,
        set: [deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)]
      )

      assert {:error, :not_found} = Platform.get_organization(org.id)
      assert {:error, :not_found} = Platform.get_organization(Ecto.UUID.generate())
      assert {:error, :not_found} = Platform.get_organization("nope")
    end
  end

  describe "overview/1" do
    test "gathers the plan, team, clients and activity", %{org: org, owner: owner} do
      trainer = user(org, :trainer)
      client = user(org, :client)
      archived = user(org, :client)
      link(trainer, client)
      link(trainer, archived, "archived")
      subscription(org, %{plan_type: "pro"})

      overview = Platform.overview(org)

      assert overview.tier == "pro"
      assert Enum.map(overview.team, & &1.id) |> Enum.sort() == Enum.sort([owner.id, trainer.id])
      assert overview.client_count == 1
      assert %Subscription{} = overview.subscription
    end
  end

  describe "set_status/3" do
    test "suspends and reactivates, and logs both", %{org: org, admin: admin} do
      assert {:ok, %{status: "suspended"}} = Platform.set_status(admin, org, "suspended")
      assert {:ok, %{status: "active"}} = Platform.set_status(admin, org, "active")

      actions =
        Repo.all(from l in ActivityLog, where: l.organization_id == ^org.id, select: l.action)

      assert Enum.sort(actions) == ["platform.active", "platform.suspended"]
    end

    test "a suspended organization is read-only", %{org: org, owner: owner, admin: admin} do
      {:ok, _} = Platform.set_status(admin, org, "suspended")

      scope = Scope.load(owner)
      refute AfyaFit.Authorization.can?(scope, :create, :workout_plan)
      assert AfyaFit.Authorization.can?(scope, :list, :workout_plan)
    end

    test "only platform admins may do it", %{org: org, owner: owner} do
      assert {:error, :forbidden} = Platform.set_status(Scope.load(owner), org, "suspended")
      assert Repo.get!(Organization, org.id).status == "active"
    end
  end

  describe "grant_plan/4" do
    test "creates a subscription when there is none", %{org: org, admin: admin} do
      assert {:ok, %Subscription{plan_type: "pro", status: "active"} = sub} =
               Platform.grant_plan(admin, org, "pro", 90)

      assert DateTime.diff(sub.current_period_end, sub.current_period_start, :day) == 90
      assert Repo.get!(Organization, org.id).plan_type == "pro"
      assert Scope.load(user(org, :trainer)).tier == "pro"
    end

    test "updates an existing subscription and clears a cancellation", %{org: org, admin: admin} do
      subscription(org, %{status: "cancelled", cancel_at_period_end: true})

      assert {:ok, %Subscription{status: "active", cancel_at_period_end: false}} =
               Platform.grant_plan(admin, org, "enterprise", 30)

      assert Repo.aggregate(from(s in Subscription, where: s.organization_id == ^org.id), :count) ==
               1
    end

    test "logs what was granted", %{org: org, admin: admin} do
      {:ok, _} = Platform.grant_plan(admin, org, "pro", 30)

      assert %ActivityLog{metadata: %{"plan" => "pro", "days" => 30}} =
               Repo.get_by!(ActivityLog, organization_id: org.id, action: "platform.grant_plan")
    end

    test "only platform admins may do it", %{org: org, owner: owner} do
      assert {:error, :forbidden} = Platform.grant_plan(Scope.load(owner), org, "pro", 30)
      refute Repo.get_by(Subscription, organization_id: org.id)
    end

    test "only known plans and lengths are accepted", %{org: org, admin: admin} do
      assert_raise FunctionClauseError, fn -> Platform.grant_plan(admin, org, "gold", 30) end
      assert_raise FunctionClauseError, fn -> Platform.grant_plan(admin, org, "pro", 7) end
    end
  end

  describe "list_subscriptions/1" do
    setup %{org: org} do
      other = organization(%{name: "Other Gym"})
      subscription(org, %{status: "past_due"})
      subscription(other, %{status: "cancelled", cancel_at_period_end: true})
      %{other: other}
    end

    test "lists every subscription with its organization", %{org: org} do
      rows = Platform.list_subscriptions()

      assert length(rows) == 2
      assert Enum.any?(rows, &(&1.organization == org.name))
    end

    test "filters by state, telling cancelling from cancelled" do
      assert [%{status: "past_due"}] = Platform.list_subscriptions("past_due")
      assert [%{cancel_at_period_end: true}] = Platform.list_subscriptions("cancelling")
      assert Platform.list_subscriptions("cancelled") == []
    end

    test "an unknown filter lists everything" do
      assert length(Platform.list_subscriptions("nonsense")) == 2
    end
  end

  describe "search_users/1" do
    test "finds people by email or name across organizations", %{org: org} do
      brian = user(org, :trainer, %{email: "brian@example.com", first_name: "Brian"})
      amina = user(organization(%{name: "Other"}), :client, %{email: "amina@example.com"})

      assert [%{id: id, organization: "Njoroge Strength"}] = Platform.search_users("brian")
      assert id == brian.id
      assert [%{id: amina_id}] = Platform.search_users("AMINA@")
      assert amina_id == amina.id
    end

    test "needs two characters and treats wildcards literally", %{org: org} do
      user(org, :trainer, %{email: "plain@example.com"})

      assert Platform.search_users("p") == []
      assert Platform.search_users("") == []
      assert Platform.search_users("%%") == []
    end

    test "leaves out deleted users", %{org: org} do
      gone = user(org, :trainer, %{email: "gone@example.com"})

      Repo.update_all(from(u in AfyaFit.Accounts.User, where: u.id == ^gone.id),
        set: [deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)]
      )

      assert Platform.search_users("gone@") == []
    end
  end
end
