defmodule AfyaFitWeb.Access do
  @moduledoc """
  What the signed-in user can see and do in the web UI, derived from the
  authorization scope rather than from role strings.

  The shell asks this module which navigation items to show and whether to
  show the account banner; LiveViews use `denial/2` to turn an authorization
  error into something to render.
  """
  use Phoenix.VerifiedRoutes,
    endpoint: AfyaFitWeb.Endpoint,
    router: AfyaFitWeb.Router,
    statics: AfyaFitWeb.static_paths()

  alias AfyaFit.Authorization
  alias AfyaFit.Authorization.{Entitlements, Scope}

  @type nav_item :: %{
          key: atom(),
          label: String.t(),
          icon: atom(),
          path: String.t(),
          pro: boolean(),
          phone: :tab | :more
        }

  @doc """
  Navigation items for the scope, in order. `pro` marks a feature the plan
  does not include yet: it stays visible so it can be discovered. Items the
  role may not use are not listed at all.
  """
  @spec nav_items(Scope.t()) :: [nav_item()]
  def nav_items(%Scope{} = scope) do
    role = Scope.role(scope)

    items = [
      {:today, "Today", :today, ~p"/trainer/dashboard", :tab, [:trainer, :org_admin], nil},
      {:home, "Home", :home, ~p"/", :tab, [:client], nil},
      {:clients, "Clients", :clients, ~p"/trainer/clients", :tab, [:trainer, :org_admin],
       {:list, :client}},
      {:workouts, "Workouts", :workouts, ~p"/trainer/workouts", :tab, [:trainer, :org_admin],
       {:list, :workout_plan}},
      {:nutrition, "Nutrition", :nutrition, ~p"/trainer/nutrition", :tab, [:trainer, :org_admin],
       {:list, :nutrition_plan}},
      {:progress, "Progress", :progress, ~p"/trainer/progress", :more, [:trainer, :org_admin],
       {:list, :progress_entry}},
      {:team, "Team", :team, ~p"/team", :more, [:org_admin], {:list, :trainer}},
      {:billing, "Billing", :billing, ~p"/billing", :more, [:org_admin, :admin],
       {:read, :subscription}},
      {:platform, "Platform", :platform, ~p"/admin/dashboard", :tab, [:admin],
       {:access, :admin_panel}}
    ]

    for {key, label, icon, path, phone, roles, permission} <- items,
        role in roles,
        permitted?(scope, permission) do
      %{key: key, label: label, icon: icon, path: path, pro: pro?(scope, key), phone: phone}
    end
  end

  defp permitted?(_scope, nil), do: true
  defp permitted?(scope, {action, resource}), do: Authorization.can?(scope, action, resource)

  # Only features that need a paid tier carry the tag, and only for non-admins.
  defp pro?(%Scope{} = scope, :nutrition),
    do: Scope.role(scope) != :admin and not Entitlements.allows?(scope.tier, :nutrition_plans)

  defp pro?(_scope, _key), do: false

  @type banner :: %{
          state: :grace | :read_only,
          message: String.t(),
          action: :update_payment | {:ask, String.t()} | nil
        }

  @doc """
  The account banner for the scope, or `nil`. Clients and platform admins
  never see one: a client keeps using their own data when the organization's
  billing lapses.
  """
  @spec banner(Scope.t(), DateTime.t()) :: banner() | nil
  def banner(%Scope{} = scope, now \\ DateTime.utc_now()) do
    if Scope.role(scope) in [:trainer, :org_admin] do
      banner_for(scope, Entitlements.billing_state(scope, now))
    end
  end

  defp banner_for(scope, :read_only) do
    %{state: :read_only, message: read_only_message(scope), action: banner_action(scope)}
  end

  defp banner_for(%Scope{subscription_status: "past_due"} = scope, :active) do
    until = scope.period_end && DateTime.add(scope.period_end, 7, :day)

    %{
      state: :grace,
      message:
        "Payment failed" <>
          if(scope.period_end, do: " on #{short_date(scope.period_end)}", else: "") <>
          ". You keep full access" <>
          if(until, do: " until #{short_date(until)}", else: "") <> ".",
      action: banner_action(scope)
    }
  end

  defp banner_for(_scope, :active), do: nil

  defp read_only_message(scope) do
    reason =
      cond do
        scope.organization_status not in [nil, "active"] ->
          "This organisation is not active."

        scope.subscription_status == "cancelled" ->
          "The subscription was cancelled."

        scope.subscription_status == "expired" ->
          "The subscription expired."

        true ->
          "Payment overdue" <>
            if(scope.period_end, do: " since #{short_date(scope.period_end)}", else: "") <> "."
      end

    "Read-only. #{reason} You can view everything; edits are paused."
  end

  defp banner_action(scope) do
    case Scope.role(scope) do
      :org_admin -> :update_payment
      _ when is_binary(scope.owner_name) -> {:ask, scope.owner_name}
      _ -> nil
    end
  end

  defp short_date(datetime), do: Calendar.strftime(datetime, "%-d %b")

  @doc """
  Turns the error from `Authorization.authorize/5` into what the UI shows:

    * `{:forbidden, message}` render the permission sign
    * `{:not_found, message}` render the not-found sign
    * `{:upgrade, details}` open the limit dialog with the feature and tier
    * `{:read_only, status}` the account is read-only
  """
  @spec denial(Scope.t(), term()) ::
          {:forbidden, String.t()}
          | {:not_found, String.t()}
          | {:upgrade, map()}
          | {:read_only, String.t()}
  def denial(%Scope{} = scope, error) do
    case error do
      {:error, :forbidden} ->
        {:forbidden, forbidden_message(scope)}

      {:error, :not_found} ->
        {:not_found, "That page is not here, or it belongs to another organisation."}

      {:error, {:upgrade_required, details}} ->
        {:upgrade,
         Map.put(details, :can_upgrade, Authorization.can?(scope, :manage, :subscription))}

      {:error, {:subscription_inactive, status}} ->
        {:read_only, status}
    end
  end

  defp forbidden_message(%Scope{owner_name: name}) when is_binary(name),
    do: "#{name} (owner) can change this. You can see your clients and plans."

  defp forbidden_message(_scope), do: "You do not have access to this page."
end
