defmodule AfyaFit.Authorization.EntitlementsTest do
  use ExUnit.Case, async: true

  alias AfyaFit.Authorization.Entitlements

  test "client limits per tier" do
    assert Entitlements.client_limit("free") == 3
    assert Entitlements.client_limit("pro") == 25
    assert Entitlements.client_limit("enterprise") == :infinity
  end

  test "gated features need a paid tier" do
    for feature <- Entitlements.features() do
      refute Entitlements.allows?("free", feature)
      assert Entitlements.allows?("pro", feature)
      assert Entitlements.allows?("enterprise", feature)
    end
  end

  test "required tier is the lowest tier that unlocks a feature" do
    assert Entitlements.required_tier(:nutrition_plans) == "pro"
  end

  test "next tier above the current one" do
    assert Entitlements.next_tier("free") == "pro"
    assert Entitlements.next_tier("pro") == "enterprise"
    assert Entitlements.next_tier("enterprise") == nil
  end

  describe "billing state" do
    @now ~U[2026-01-15 00:00:00Z]

    test "active and missing subscriptions are active" do
      assert Entitlements.billing_state(%{subscription_status: "active"}, @now) == :active
      assert Entitlements.billing_state(%{subscription_status: nil}, @now) == :active
    end

    test "past_due keeps full access for 7 days after period end" do
      inside = %{subscription_status: "past_due", period_end: ~U[2026-01-10 00:00:00Z]}
      assert Entitlements.billing_state(inside, @now) == :active

      outside = %{subscription_status: "past_due", period_end: ~U[2026-01-01 00:00:00Z]}
      assert Entitlements.billing_state(outside, @now) == :read_only
    end

    test "cancelled, expired and inactive organizations are read-only" do
      for status <- ["cancelled", "expired"] do
        assert Entitlements.billing_state(%{subscription_status: status}, @now) == :read_only
      end

      suspended = %{subscription_status: "active", organization_status: "suspended"}
      assert Entitlements.billing_state(suspended, @now) == :read_only
    end
  end
end
