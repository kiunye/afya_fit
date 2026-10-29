defmodule AfyaFit.AuthorizationTest do
  use ExUnit.Case, async: true

  import AfyaFit.AuthorizationFixtures

  alias AfyaFit.Accounts.User
  alias AfyaFit.Authorization
  alias AfyaFit.Nutrition.NutritionPlan
  alias AfyaFit.Schedule.CalendarEvent
  alias AfyaFit.Tasks.Task
  alias AfyaFit.Tracking.ProgressEntry
  alias AfyaFit.Workouts.{ClientWorkout, WorkoutPlan}

  defp plan(attrs \\ %{}) do
    struct!(WorkoutPlan, Map.merge(%{organization_id: org_a(), trainer_id: "trainer-1"}, attrs))
  end

  defp other_plan(attrs \\ %{}), do: plan(Map.merge(%{trainer_id: "trainer-2"}, attrs))

  defp in_org_client, do: %User{organization_id: org_a()}

  defp client_workout(client_id),
    do: struct!(ClientWorkout, client_id: client_id, client: in_org_client())

  defp progress(client_id),
    do: struct!(ProgressEntry, client_id: client_id, client: in_org_client())

  defp auth(scope, action, subject, record \\ nil, opts \\ []) do
    Authorization.authorize(scope, action, subject, record, opts)
  end

  describe "tenant isolation" do
    test "records from another organization are not found" do
      record = plan(%{organization_id: org_b()})

      for role <- [:trainer, :org_admin, :client] do
        assert {:error, :not_found} = Authorization.authorize(scope(role), :read, record)
      end
    end

    test "platform admin can read across organizations" do
      assert :ok =
               Authorization.authorize(scope(:admin), :read, plan(%{organization_id: org_b()}))
    end
  end

  describe "role permissions" do
    test "clients cannot touch workout plans" do
      assert {:error, :forbidden} = auth(scope(:client), :list, :workout_plan)
      assert {:error, :forbidden} = auth(scope(:client), :create, :workout_plan)
    end

    test "trainers cannot manage billing, org admins can" do
      assert {:error, :forbidden} = auth(scope(:trainer), :manage, :subscription)
      assert :ok = auth(scope(:org_admin), :manage, :subscription)
    end

    test "only org admins manage trainers and reassign clients" do
      assert {:error, :forbidden} = auth(scope(:trainer), :create, :trainer)
      assert :ok = auth(scope(:org_admin), :create, :trainer)
      assert {:error, :forbidden} = auth(scope(:trainer), :reassign, :client)
      assert :ok = auth(scope(:org_admin), :reassign, :client)
    end

    test "platform admin reads plans, manages subscriptions, cannot edit plans" do
      assert :ok = Authorization.authorize(scope(:admin), :read, plan())
      assert {:error, :forbidden} = Authorization.authorize(scope(:admin), :update, plan())
      assert :ok = auth(scope(:admin), :manage, :subscription)
      assert :ok = auth(scope(:admin), :access, :admin_panel)
      assert {:error, :forbidden} = auth(scope(:org_admin), :access, :admin_panel)
    end

    test "unknown resources are rejected" do
      assert {:error, :forbidden} = auth(scope(:admin), :read, :nonsense)
    end
  end

  describe "workout plan attributes" do
    test "trainer owns, reads public and template plans, cannot write others'" do
      s = scope(:trainer)
      assert :ok = Authorization.authorize(s, :update, plan())
      assert :ok = Authorization.authorize(s, :read, other_plan(%{is_public: true}))
      assert :ok = Authorization.authorize(s, :read, other_plan(%{is_template: true}))
      assert :ok = Authorization.authorize(s, :duplicate, other_plan(%{is_public: true}))
      assert {:error, :forbidden} = Authorization.authorize(s, :read, other_plan())

      assert {:error, :forbidden} =
               Authorization.authorize(s, :update, other_plan(%{is_public: true}))

      assert {:error, :forbidden} = Authorization.authorize(s, :delete, other_plan())
    end

    test "org admin manages every plan in the organization" do
      s = scope(:org_admin)
      assert :ok = Authorization.authorize(s, :update, other_plan())
      assert :ok = Authorization.authorize(s, :delete, other_plan())
    end
  end

  describe "client-scoped records" do
    test "trainer only reaches linked clients" do
      s = scope(:trainer, client_ids: ["client-1"])
      assert :ok = Authorization.authorize(s, :update, client_workout("client-1"))

      assert {:error, :forbidden} =
               Authorization.authorize(s, :update, client_workout("client-9"))

      assert :ok = Authorization.authorize(s, :read, progress("client-1"))
      assert {:error, :forbidden} = Authorization.authorize(s, :read, progress("client-9"))
    end

    test "linked clients come from the scope, not the organization" do
      assert {:error, :forbidden} =
               Authorization.authorize(scope(:trainer), :read, progress("client-1"))
    end

    test "org admin reaches every client in the organization" do
      assert :ok = Authorization.authorize(scope(:org_admin), :read, progress("client-9"))
    end

    test "client reaches only own records and cannot delete progress" do
      s = scope(:client, user: %{id: "client-1"})
      assert :ok = Authorization.authorize(s, :read, progress("client-1"))
      assert :ok = Authorization.authorize(s, :update, progress("client-1"))
      assert {:error, :forbidden} = Authorization.authorize(s, :read, progress("client-2"))
      assert {:error, :forbidden} = Authorization.authorize(s, :delete, progress("client-1"))
      assert :ok = Authorization.authorize(s, :complete, client_workout("client-1"))

      assert {:error, :forbidden} =
               Authorization.authorize(s, :update, client_workout("client-1"))
    end

    test "records without an organization need a preloaded client" do
      s = scope(:trainer, client_ids: ["client-1"])

      assert_raise ArgumentError, fn ->
        Authorization.authorize(s, :read, struct!(ProgressEntry, client_id: "client-1"))
      end
    end
  end

  describe "tasks, nutrition and calendar" do
    test "trainer reaches own and linked-client tasks" do
      s = scope(:trainer, client_ids: ["client-1"])
      task = fn attrs -> struct!(Task, Map.merge(%{organization_id: org_a()}, attrs)) end

      assert :ok = Authorization.authorize(s, :update, task.(%{trainer_id: "trainer-1"}))

      assert :ok =
               Authorization.authorize(
                 s,
                 :read,
                 task.(%{trainer_id: "t2", client_id: "client-1"})
               )

      assert {:error, :forbidden} =
               Authorization.authorize(
                 s,
                 :read,
                 task.(%{trainer_id: "t2", client_id: "client-9"})
               )
    end

    test "client completes only their own tasks" do
      s = scope(:client, user: %{id: "client-1"})
      mine = struct!(Task, organization_id: org_a(), client_id: "client-1")
      theirs = struct!(Task, organization_id: org_a(), client_id: "client-2")
      assert :ok = Authorization.authorize(s, :complete, mine)
      assert {:error, :forbidden} = Authorization.authorize(s, :complete, theirs)
      assert {:error, :forbidden} = auth(s, :create, :task)
    end

    test "nutrition plan: owner, linked client read, template read" do
      s = scope(:trainer, client_ids: ["client-1"])
      np = fn attrs -> struct!(NutritionPlan, Map.merge(%{organization_id: org_a()}, attrs)) end

      assert :ok = Authorization.authorize(s, :update, np.(%{trainer_id: "trainer-1"}))

      assert :ok =
               Authorization.authorize(s, :read, np.(%{trainer_id: "t2", client_id: "client-1"}))

      assert :ok = Authorization.authorize(s, :read, np.(%{trainer_id: "t2", is_template: true}))
      assert {:error, :forbidden} = Authorization.authorize(s, :read, np.(%{trainer_id: "t2"}))

      c = scope(:client, user: %{id: "client-1"})
      assigned = np.(%{trainer_id: "t2", client_id: "client-1"})
      assert :ok = Authorization.authorize(c, :read, assigned)
      assert {:error, :forbidden} = Authorization.authorize(c, :update, assigned)
    end

    test "calendar events belong to their creator" do
      event = struct!(CalendarEvent, organization_id: org_a(), user_id: "trainer-1")
      other = struct!(CalendarEvent, organization_id: org_a(), user_id: "t2")

      assert :ok = Authorization.authorize(scope(:trainer), :update, event)
      assert {:error, :forbidden} = Authorization.authorize(scope(:trainer), :update, other)
      assert :ok = Authorization.authorize(scope(:org_admin), :update, other)
    end
  end

  describe "user records" do
    test "client reads and updates only themselves" do
      s = scope(:client, user: %{id: "client-1"})
      me = %User{id: "client-1", role: "client", organization_id: org_a()}
      other = %User{id: "client-2", role: "client", organization_id: org_a()}
      assert :ok = Authorization.authorize(s, :read, me)
      assert :ok = Authorization.authorize(s, :update, me)
      assert {:error, :forbidden} = Authorization.authorize(s, :read, other)
    end

    test "trainer reaches linked clients; org admin reaches all clients and trainers" do
      linked = %User{id: "client-1", role: "client", organization_id: org_a()}
      unlinked = %User{id: "client-2", role: "client", organization_id: org_a()}
      s = scope(:trainer, client_ids: ["client-1"])
      assert :ok = Authorization.authorize(s, :update, linked)
      assert {:error, :forbidden} = Authorization.authorize(s, :update, unlinked)

      oa = scope(:org_admin)
      assert :ok = Authorization.authorize(oa, :update, unlinked)
      other_trainer = %User{id: "t2", role: "trainer", organization_id: org_a()}
      assert :ok = Authorization.authorize(oa, :delete, other_trainer)
    end
  end

  describe "feature entitlements" do
    test "free tier cannot write gated features but can still read existing data" do
      s = scope(:trainer, tier: "free")

      assert {:error, {:upgrade_required, %{feature: :nutrition_plans, required_tier: "pro"}}} =
               auth(s, :create, :nutrition_plan)

      assert :ok = auth(s, :list, :nutrition_plan)

      assert {:error, {:upgrade_required, %{feature: :calendar}}} =
               auth(s, :create, :calendar_event)

      assert {:error, {:upgrade_required, %{feature: :progress_analytics}}} =
               auth(s, :analytics, :progress_entry)

      assert {:error, {:upgrade_required, %{feature: :progress_photos}}} =
               auth(s, :upload_photo, :progress_entry)

      assert {:error, {:upgrade_required, %{feature: :task_automation}}} =
               auth(s, :automate, :task)

      assert :ok = auth(s, :create, :workout_plan)
      assert :ok = auth(scope(:trainer, tier: "pro"), :create, :nutrition_plan)
    end

    test "client limit is enforced when adding clients" do
      full = scope(:trainer, tier: "free", client_count: 3)

      assert {:error, {:upgrade_required, %{feature: :clients, required_tier: "pro"}}} =
               auth(full, :create, :client)

      assert :ok = auth(scope(:trainer, tier: "free", client_count: 2), :create, :client)

      assert :ok =
               auth(scope(:trainer, tier: "enterprise", client_count: 10_000), :create, :client)
    end

    test "platform admin ignores entitlements" do
      assert :ok = auth(scope(:admin, tier: "free"), :manage, :subscription)
    end
  end

  describe "read-only billing states" do
    test "writes by trainers and org admins are blocked, reads are not" do
      for status <- ["cancelled", "expired"], role <- [:trainer, :org_admin] do
        s = scope(role, subscription_status: status)

        assert {:error, {:subscription_inactive, ^status}} = auth(s, :create, :workout_plan)
        assert :ok = auth(s, :list, :workout_plan)
      end
    end

    test "billing management stays available so the account can be reactivated" do
      s = scope(:org_admin, subscription_status: "cancelled")
      assert :ok = auth(s, :manage, :subscription)
    end

    test "clients keep working with their own data" do
      s = scope(:client, user: %{id: "client-1"}, subscription_status: "expired")
      assert :ok = Authorization.authorize(s, :update, progress("client-1"))
      assert :ok = Authorization.authorize(s, :read, progress("client-1"))
    end

    test "past_due keeps full access during the grace period" do
      now = ~U[2026-01-15 00:00:00Z]

      inside =
        scope(:trainer, subscription_status: "past_due", period_end: ~U[2026-01-12 00:00:00Z])

      assert :ok = auth(inside, :create, :workout_plan, nil, now: now)

      outside =
        scope(:trainer, subscription_status: "past_due", period_end: ~U[2026-01-01 00:00:00Z])

      assert {:error, {:subscription_inactive, "past_due"}} =
               auth(outside, :create, :workout_plan, nil, now: now)
    end
  end

  test "can?/3 is a boolean convenience" do
    assert Authorization.can?(scope(:trainer), :create, :workout_plan)
    refute Authorization.can?(scope(:client), :create, :workout_plan)
  end

  test "permissions/1 lists role capabilities" do
    perms = Authorization.permissions(scope(:client))
    assert :complete in perms.client_workout
    refute Map.has_key?(perms, :workout_plan)
  end
end
