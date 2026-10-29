defmodule AfyaFitWeb.SupportEmail do
  @moduledoc """
  Notifications to the people who run Afya Fit.
  """
  import Swoosh.Email

  @from {"Afya Fit", "noreply@afyafit.com"}

  @doc """
  Tells support that an organization hit its plan. `args` is the job's string-keyed
  map from `AfyaFit.PlanBlocks`.
  """
  def plan_blocked(args, address) do
    new()
    |> to(address)
    |> from(@from)
    |> subject(subject(args))
    |> text_body(body(args))
  end

  defp subject(%{"kind" => "subscription_inactive"} = args),
    do: "Read-only account: #{args["organization_name"]}"

  defp subject(args),
    do: "Wants #{label(args["feature"])}: #{args["organization_name"]} (#{args["tier"]})"

  defp body(%{"kind" => "subscription_inactive"} = args) do
    """
    #{args["user_name"]} (#{args["user_role"]}, #{args["user_email"]}) tried to change data, but
    the account is read-only (#{args["status"]}).

    Organisation: #{args["organization_name"]}
    Plan: #{args["tier"]}
    """
  end

  defp body(args) do
    """
    #{args["user_name"]} (#{args["user_role"]}, #{args["user_email"]}) was stopped by the
    #{args["tier"]} plan.

    Wanted: #{label(args["feature"])}#{needs(args["required_tier"])}
    Organisation: #{args["organization_name"]}
    Clients: #{args["client_count"]}

    This is the only email for this organisation and feature in the next 24 hours.
    """
  end

  defp needs(nil), do: ""
  defp needs(tier), do: " (needs #{tier})"

  defp label("clients"), do: "more clients"
  defp label(feature), do: feature |> String.replace("_", " ")
end
