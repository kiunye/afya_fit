defmodule AfyaFitWeb.API.JSON.AccessJSON do
  @moduledoc """
  What the signed-in user can do, for clients that decide what to show (the
  mobile app). Sent with `/auth/me`, login and registration.

    * `permissions`: resource => actions the role may attempt. Role-level only:
      the server still enforces per-record rules, so a client uses this to hide
      or pause controls, never to authorize.
    * `entitlements`: the plan (`tier`), client limit and count, which Pro
      features are on, and the billing state (`state` is `active` or
      `read_only`, with the `reason`, `since` and `until` dates).
    * `organization`: its name and who to ask about upgrades.
  """

  alias AfyaFit.Authorization
  alias AfyaFit.Authorization.{Entitlements, Scope}

  @spec build(Scope.t()) :: map()
  def build(%Scope{} = scope) do
    %{
      permissions: permissions(scope),
      entitlements: entitlements(scope),
      organization: %{
        name: scope.organization && scope.organization.name,
        owner_name: scope.owner_name
      }
    }
  end

  defp permissions(scope) do
    for {resource, actions} <- Authorization.permissions(scope), into: %{} do
      {to_string(resource), Enum.map(actions, &to_string/1)}
    end
  end

  defp entitlements(scope) do
    billing = Scope.billing(scope)

    %{
      tier: scope.tier,
      client_limit: client_limit(scope.tier),
      client_count: scope.client_count,
      features: features(scope),
      billing: %{
        state: to_string(billing.state),
        reason: billing.reason && to_string(billing.reason),
        since: billing.since,
        until: billing.until
      }
    }
  end

  # `nil` means no limit.
  defp client_limit(tier) do
    case Entitlements.client_limit(tier) do
      :infinity -> nil
      limit -> limit
    end
  end

  # Platform admins are not limited by a plan.
  defp features(scope) do
    for feature <- Entitlements.features(), into: %{} do
      {to_string(feature),
       Scope.role(scope) == :admin or Entitlements.allows?(scope.tier, feature)}
    end
  end
end
