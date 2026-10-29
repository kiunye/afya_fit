defmodule AfyaFit.PlanBlocks do
  @moduledoc """
  Records that someone was stopped by their plan: a Pro feature on Free, the
  client limit, or a read-only account.

  Every block is logged as one structured line. It also queues an email to the
  support address (`:support_email`), at most one per organization, kind and
  feature per day, so a stuck app cannot flood the inbox. This is how the owner
  hears that a customer wants to upgrade.
  """
  require Logger

  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Workers.PlanBlockedWorker

  @type error :: {:upgrade_required, %{feature: atom()}} | {:subscription_inactive, String.t()}

  @doc "Records the block described by an authorization error; other errors are ignored."
  @spec record(Scope.t() | nil, term()) :: :ok
  def record(%Scope{} = scope, {:error, error}), do: record(scope, error)

  def record(%Scope{} = scope, {:upgrade_required, %{feature: feature} = details}) do
    track(scope, "upgrade_required", to_string(feature), details[:required_tier])
  end

  def record(%Scope{} = scope, {:subscription_inactive, status}) do
    track(scope, "subscription_inactive", "read_only", nil, status)
  end

  def record(_scope, _other), do: :ok

  defp track(scope, kind, feature, required_tier, status \\ nil) do
    args = %{
      kind: kind,
      feature: feature,
      required_tier: required_tier,
      status: status,
      tier: scope.tier,
      organization_id: scope.user.organization_id,
      organization_name: scope.organization && scope.organization.name,
      user_id: scope.user.id,
      user_name: "#{scope.user.first_name} #{scope.user.last_name}",
      user_email: scope.user.email,
      user_role: scope.user.role,
      client_count: scope.client_count
    }

    Logger.warning(
      "plan_blocked kind=#{kind} feature=#{feature} tier=#{scope.tier} " <>
        "organization_id=#{args.organization_id} user_id=#{args.user_id}"
    )

    {:ok, _job} = args |> PlanBlockedWorker.new() |> Oban.insert()
    :ok
  end
end
