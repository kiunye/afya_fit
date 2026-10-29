defmodule AfyaFit.Authorization.BillingStatus do
  @moduledoc """
  Whether an organization may write data right now, and why, derived once from
  its subscription and organization status.

  Everything that talks about billing state (the write gate in
  `AfyaFit.Authorization`, the account banner, the Billing screen) reads this
  value instead of re-deriving the rules.

    * `state` is `:active` (writes allowed) or `:read_only`.
    * `reason` says which rule applied: `nil` (healthy), `:grace` (payment failed,
      still inside the 7-day grace period), `:cancelling` (cancelled at period
      end, paid period not over), or, when read-only, `:past_due`, `:cancelled`,
      `:expired` or `:inactive` (the organization itself is not active).
    * `since` is when the problem started (the end of the last paid period).
    * `until` is the last moment of full access for `:grace` and `:cancelling`.
  """

  @grace_seconds 7 * 24 * 60 * 60

  defstruct [:state, :reason, :since, :until]

  @type reason :: nil | :grace | :cancelling | :past_due | :cancelled | :expired | :inactive

  @type t :: %__MODULE__{
          state: :active | :read_only,
          reason: reason(),
          since: DateTime.t() | nil,
          until: DateTime.t() | nil
        }

  @doc """
  Builds the status from any map carrying `:subscription_status`,
  `:organization_status`, `:period_end` and `:cancel_at_period_end` (a scope, or
  fields taken from a subscription). Missing keys mean "nothing wrong".
  """
  @spec build(map(), DateTime.t()) :: t()
  def build(source, now) do
    period_end = Map.get(source, :period_end)

    cond do
      Map.get(source, :organization_status, "active") not in [nil, "active"] ->
        read_only(:inactive, nil)

      Map.get(source, :subscription_status) == "expired" ->
        read_only(:expired, period_end)

      Map.get(source, :subscription_status) == "cancelled" ->
        cancelled(source, period_end, now)

      Map.get(source, :subscription_status) == "past_due" ->
        past_due(period_end, now)

      true ->
        %__MODULE__{state: :active}
    end
  end

  @doc "True when the organization may write."
  @spec writable?(t()) :: boolean()
  def writable?(%__MODULE__{state: state}), do: state == :active

  # Cancelled "at period end" keeps working until the period it paid for ends.
  defp cancelled(%{cancel_at_period_end: true}, %DateTime{} = period_end, now) do
    if DateTime.compare(now, period_end) == :lt,
      do: %__MODULE__{state: :active, reason: :cancelling, until: period_end},
      else: read_only(:cancelled, period_end)
  end

  defp cancelled(_source, period_end, _now), do: read_only(:cancelled, period_end)

  defp past_due(%DateTime{} = period_end, now) do
    until = DateTime.add(period_end, @grace_seconds, :second)

    if DateTime.compare(now, until) != :gt,
      do: %__MODULE__{state: :active, reason: :grace, since: period_end, until: until},
      else: read_only(:past_due, period_end)
  end

  defp past_due(nil, _now), do: read_only(:past_due, nil)

  defp read_only(reason, since), do: %__MODULE__{state: :read_only, reason: reason, since: since}
end
