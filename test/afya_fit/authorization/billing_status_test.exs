defmodule AfyaFit.Authorization.BillingStatusTest do
  use ExUnit.Case, async: true

  alias AfyaFit.Authorization.BillingStatus

  @now ~U[2026-01-15 00:00:00Z]

  defp build(source), do: BillingStatus.build(source, @now)

  test "no subscription, or an active one, is healthy" do
    assert %{state: :active, reason: nil} = build(%{})
    assert %{state: :active, reason: nil} = build(%{subscription_status: nil})
    assert %{state: :active, reason: nil} = build(%{subscription_status: "active"})
  end

  describe "past_due" do
    test "keeps full access for 7 days after the period ended, and says until when" do
      status = build(%{subscription_status: "past_due", period_end: ~U[2026-01-10 00:00:00Z]})

      assert %{state: :active, reason: :grace} = status
      assert status.since == ~U[2026-01-10 00:00:00Z]
      assert status.until == ~U[2026-01-17 00:00:00Z]
    end

    test "is read-only once the grace period is over" do
      status = build(%{subscription_status: "past_due", period_end: ~U[2026-01-01 00:00:00Z]})

      assert %{state: :read_only, reason: :past_due, since: ~U[2026-01-01 00:00:00Z]} = status
    end

    test "without a period end is read-only" do
      assert %{state: :read_only, reason: :past_due} = build(%{subscription_status: "past_due"})
    end
  end

  describe "cancelled" do
    test "at period end keeps access until the paid period ends" do
      source = %{
        subscription_status: "cancelled",
        cancel_at_period_end: true,
        period_end: ~U[2026-02-01 00:00:00Z]
      }

      assert %{state: :active, reason: :cancelling, until: ~U[2026-02-01 00:00:00Z]} =
               build(source)

      assert %{state: :read_only, reason: :cancelled} =
               BillingStatus.build(source, ~U[2026-02-02 00:00:00Z])
    end

    test "without a paid period left is read-only" do
      assert %{state: :read_only, reason: :cancelled} =
               build(%{subscription_status: "cancelled", cancel_at_period_end: false})
    end
  end

  test "expired and inactive organisations are read-only" do
    assert %{state: :read_only, reason: :expired} = build(%{subscription_status: "expired"})

    assert %{state: :read_only, reason: :inactive} =
             build(%{subscription_status: "active", organization_status: "suspended"})
  end

  test "writable?/1" do
    assert BillingStatus.writable?(build(%{}))
    refute BillingStatus.writable?(build(%{subscription_status: "expired"}))
  end
end
