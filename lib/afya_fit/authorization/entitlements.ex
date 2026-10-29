defmodule AfyaFit.Authorization.Entitlements do
  @moduledoc """
  What each subscription tier includes, and how billing state limits writes.

  Change the tier matrix by editing `@required_tier` and `@client_limits`.
  """

  @tiers ["free", "pro", "enterprise"]
  @grace_seconds 7 * 24 * 60 * 60

  @required_tier %{
    nutrition_plans: "pro",
    progress_analytics: "pro",
    task_automation: "pro",
    calendar: "pro",
    progress_photos: "pro"
  }

  @client_limits %{"free" => 3, "pro" => 25, "enterprise" => :infinity}

  @type tier :: String.t()
  @type feature ::
          :nutrition_plans | :progress_analytics | :task_automation | :calendar | :progress_photos

  @spec features() :: [feature()]
  def features, do: Map.keys(@required_tier)

  @spec required_tier(feature()) :: tier()
  def required_tier(feature), do: Map.fetch!(@required_tier, feature)

  @spec allows?(tier(), feature()) :: boolean()
  def allows?(tier, feature), do: tier_rank(tier) >= tier_rank(required_tier(feature))

  @spec client_limit(tier()) :: pos_integer() | :infinity
  def client_limit(tier), do: Map.get(@client_limits, tier, @client_limits["free"])

  @doc "The tier above `tier`, or `nil` when it is already the highest."
  @spec next_tier(tier()) :: tier() | nil
  def next_tier(tier), do: Enum.at(@tiers, tier_rank(tier) + 1)

  @doc """
  Whether the organization may currently write data.

  Takes any map carrying `:subscription_status`, `:organization_status` and
  `:period_end`. A `past_due` subscription keeps full access for 7 days after
  its period ended; cancelled and expired subscriptions, and organizations that
  are not active, are read-only.
  """
  @spec billing_state(map(), DateTime.t()) :: :active | :read_only
  def billing_state(scope, now) do
    cond do
      Map.get(scope, :organization_status, "active") not in [nil, "active"] -> :read_only
      Map.get(scope, :subscription_status) in ["cancelled", "expired"] -> :read_only
      Map.get(scope, :subscription_status) == "past_due" -> past_due_state(scope, now)
      true -> :active
    end
  end

  defp past_due_state(%{period_end: %DateTime{} = period_end}, now) do
    if DateTime.diff(now, period_end, :second) <= @grace_seconds, do: :active, else: :read_only
  end

  defp past_due_state(_scope, _now), do: :read_only

  defp tier_rank(tier), do: Enum.find_index(@tiers, &(&1 == tier)) || 0
end
