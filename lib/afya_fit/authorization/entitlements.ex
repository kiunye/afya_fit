defmodule AfyaFit.Authorization.Entitlements do
  @moduledoc """
  What each subscription tier includes. Whether billing allows writes at all is
  `AfyaFit.Authorization.BillingStatus`.

  Change the tier matrix by editing `@required_tier` and `@client_limits`.
  """

  @tiers ["free", "pro", "enterprise"]

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

  defp tier_rank(tier), do: Enum.find_index(@tiers, &(&1 == tier)) || 0
end
