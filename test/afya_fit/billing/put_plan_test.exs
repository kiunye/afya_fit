defmodule AfyaFit.Billing.PutPlanTest do
  use AfyaFit.DataCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Billing
  alias AfyaFit.Billing.Subscription
  alias AfyaFit.Organizations.Organization
  alias AfyaFit.Repo

  @now ~U[2026-10-30 09:00:00Z]

  setup do
    %{org: organization(%{plan_type: "free"})}
  end

  defp sub(org), do: Repo.get_by(Subscription, organization_id: org.id)

  test "creates the subscription and moves the organization to the plan", %{org: org} do
    assert {:ok, %Subscription{plan_type: "pro", status: "active"}} =
             Billing.put_plan(org, "pro", 30, now: @now)

    assert sub(org).current_period_start == @now
    assert sub(org).current_period_end == ~U[2026-11-29 09:00:00Z]
    assert Repo.get!(Organization, org.id).plan_type == "pro"
  end

  test "updates the one subscription instead of adding another", %{org: org} do
    {:ok, _} = Billing.put_plan(org, "pro", 30, now: @now)
    {:ok, _} = Billing.put_plan(org, "enterprise", 90, now: @now)

    assert Repo.aggregate(Subscription, :count) == 1
    assert %{plan_type: "enterprise"} = sub(org)
  end

  test "without extend, a second grant restarts the period", %{org: org} do
    {:ok, _} = Billing.put_plan(org, "pro", 30, now: @now)
    later = DateTime.add(@now, 10, :day)
    {:ok, _} = Billing.put_plan(org, "pro", 30, now: later)

    assert sub(org).current_period_start == later
    assert sub(org).current_period_end == DateTime.add(later, 30, :day)
  end

  describe "extend: true" do
    test "adds to the end of the current period on the same plan", %{org: org} do
      {:ok, first} = Billing.put_plan(org, "pro", 30, now: @now)
      later = DateTime.add(@now, 10, :day)

      {:ok, second} = Billing.put_plan(org, "pro", 30, extend: true, now: later)

      assert second.current_period_start == first.current_period_start
      assert second.current_period_end == DateTime.add(first.current_period_end, 30, :day)
    end

    test "starts a new period on another plan", %{org: org} do
      {:ok, _} = Billing.put_plan(org, "pro", 30, now: @now)
      later = DateTime.add(@now, 10, :day)

      {:ok, second} = Billing.put_plan(org, "enterprise", 30, extend: true, now: later)

      assert second.current_period_start == later
      assert second.current_period_end == DateTime.add(later, 30, :day)
    end

    test "starts a new period once the old one has ended", %{org: org} do
      {:ok, _} = Billing.put_plan(org, "pro", 30, now: @now)
      much_later = DateTime.add(@now, 60, :day)

      {:ok, second} = Billing.put_plan(org, "pro", 30, extend: true, now: much_later)

      assert second.current_period_start == much_later
    end

    test "does not extend an account that is not active", %{org: org} do
      subscription(org, %{
        status: "past_due",
        plan_type: "pro",
        current_period_end: DateTime.add(@now, 5, :day)
      })

      {:ok, saved} = Billing.put_plan(org, "pro", 30, extend: true, now: @now)

      assert saved.status == "active"
      assert saved.current_period_start == @now
    end
  end

  test "clears a pending cancellation", %{org: org} do
    subscription(org, %{status: "cancelled", cancel_at_period_end: true, plan_type: "pro"})

    {:ok, saved} = Billing.put_plan(org, "pro", 30, now: @now)

    assert %{status: "active", cancel_at_period_end: false, cancelled_at: nil} = saved
  end

  test "only real plans are accepted", %{org: org} do
    assert_raise FunctionClauseError, fn -> Billing.put_plan(org, "gold", 30) end
  end

  test "cancelling keeps access to the end of the period", %{org: org} do
    {:ok, saved} = Billing.put_plan(org, "pro", 30, now: @now)

    assert {:ok, %{status: "cancelled", cancel_at_period_end: true}} =
             Billing.cancel_subscription(saved)
  end
end
