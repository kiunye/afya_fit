defmodule AfyaFitWeb.AccessTest do
  use ExUnit.Case, async: true

  import AfyaFit.AuthorizationFixtures

  alias AfyaFitWeb.Access

  defp keys(scope), do: for(item <- Access.nav_items(scope), do: item.key)

  describe "nav_items/1" do
    test "org admins get the whole trainer set plus Team and Billing" do
      assert keys(scope(:org_admin)) ==
               [:today, :clients, :workouts, :nutrition, :progress, :team, :billing]
    end

    test "trainers never see Team or Billing" do
      assert keys(scope(:trainer)) == [:today, :clients, :workouts, :nutrition, :progress]
    end

    test "clients only get Home" do
      assert keys(scope(:client)) == [:home]
    end

    test "platform admins get Platform, Subscriptions and Users" do
      assert keys(scope(:admin)) == [:platform, :subscriptions, :users]
    end

    test "Nutrition is tagged Pro on the Free plan but stays visible" do
      free = Access.nav_items(scope(:trainer, tier: "free"))
      pro = Access.nav_items(scope(:trainer, tier: "pro"))

      assert Enum.find(free, &(&1.key == :nutrition)).pro
      refute Enum.find(pro, &(&1.key == :nutrition)).pro
    end

    test "phone tab bar keeps five slots: four tabs and the rest under More" do
      items = Access.nav_items(scope(:org_admin))

      assert for(i <- items, i.phone == :tab, do: i.key) == [
               :today,
               :clients,
               :workouts,
               :nutrition
             ]

      assert for(i <- items, i.phone == :more, do: i.key) == [:progress, :team, :billing]
    end
  end

  describe "banner/2" do
    @now ~U[2026-10-29 12:00:00Z]

    test "no banner when billing is healthy" do
      assert Access.banner(scope(:org_admin), @now) == nil
    end

    test "past_due inside the grace period is an outlined notice with full access" do
      scope =
        scope(:org_admin, subscription_status: "past_due", period_end: ~U[2026-10-25 00:00:00Z])

      assert %{state: :grace, action: :update_payment, message: message} =
               Access.banner(scope, @now)

      assert message =~ "Payment failed on 25 Oct"
      assert message =~ "until 1 Nov"
    end

    test "past_due after grace, cancelled and expired are read-only" do
      overdue =
        scope(:org_admin, subscription_status: "past_due", period_end: ~U[2026-10-14 00:00:00Z])

      assert %{state: :read_only, message: m} = Access.banner(overdue, @now)
      assert m =~ "Payment overdue since 14 Oct"

      for status <- ["cancelled", "expired"] do
        assert %{state: :read_only} =
                 Access.banner(scope(:org_admin, subscription_status: status), @now)
      end
    end

    test "trainers are told who to ask; org admins get the action" do
      cancelled = [subscription_status: "cancelled", owner_name: "Wanjiru Njoroge"]

      assert %{action: {:ask, "Wanjiru Njoroge"}} =
               Access.banner(scope(:trainer, cancelled), @now)

      assert %{action: :update_payment} = Access.banner(scope(:org_admin, cancelled), @now)
    end

    test "clients and platform admins never see a banner" do
      for role <- [:client, :admin] do
        assert Access.banner(scope(role, subscription_status: "cancelled"), @now) == nil
      end
    end
  end

  describe "denial/2" do
    test "maps each authorization error to a UI outcome" do
      s = scope(:trainer, owner_name: "Wanjiru Njoroge")

      assert {:forbidden, message} = Access.denial(s, {:error, :forbidden})
      assert message =~ "Wanjiru Njoroge"
      assert {:not_found, _} = Access.denial(s, {:error, :not_found})

      assert {:read_only, "cancelled"} =
               Access.denial(s, {:error, {:subscription_inactive, "cancelled"}})

      assert {:upgrade, %{feature: :clients, required_tier: "pro", can_upgrade: false}} =
               Access.denial(
                 s,
                 {:error, {:upgrade_required, %{feature: :clients, required_tier: "pro"}}}
               )

      assert {:upgrade, %{can_upgrade: true}} =
               Access.denial(
                 scope(:org_admin),
                 {:error, {:upgrade_required, %{feature: :clients, required_tier: "pro"}}}
               )
    end
  end
end
