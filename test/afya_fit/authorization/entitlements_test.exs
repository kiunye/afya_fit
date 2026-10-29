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
end
