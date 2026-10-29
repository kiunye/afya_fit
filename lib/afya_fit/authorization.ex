defmodule AfyaFit.Authorization do
  @moduledoc """
  Single entry point for deciding whether a requester may perform an action.

      scope = AfyaFit.Authorization.Scope.load(user)

      case Authorization.authorize(scope, :update, workout_plan) do
        :ok -> ...
        {:error, :not_found} -> ...
        {:error, :forbidden} -> ...
        {:error, {:upgrade_required, %{feature: feature, required_tier: tier}}} -> ...
        {:error, {:subscription_inactive, status}} -> ...
      end

  The subject is either a resource type atom (`:workout_plan`) for checks that
  need no record, such as `:create` or `:list`, or a loaded struct. Checks run
  in this order, and the first failure wins:

    1. tenant isolation: a record from another organization is `:not_found`
    2. role permissions (`Permissions`)
    3. attribute rules (`Policy`)
    4. billing state: read-only organizations cannot write
    5. tier entitlements and client limits (`Entitlements`)

  Records that carry no `organization_id` of their own (progress entries,
  assigned workouts) must have their `client` preloaded.
  """

  alias AfyaFit.Accounts.User
  alias AfyaFit.Authorization.{Entitlements, Permissions, Policy, Scope}

  @struct_types %{
    AfyaFit.Workouts.WorkoutPlan => :workout_plan,
    AfyaFit.Workouts.ClientWorkout => :client_workout,
    AfyaFit.Nutrition.NutritionPlan => :nutrition_plan,
    AfyaFit.Tracking.ProgressEntry => :progress_entry,
    AfyaFit.Tasks.Task => :task,
    AfyaFit.Schedule.CalendarEvent => :calendar_event,
    AfyaFit.Billing.Subscription => :subscription,
    AfyaFit.Billing.ClientSubscription => :client_subscription
  }

  @gated_writes %{
    nutrition_plan: :nutrition_plans,
    calendar_event: :calendar
  }

  @gated_actions %{
    {:progress_entry, :analytics} => :progress_analytics,
    {:progress_entry, :upload_photo} => :progress_photos,
    {:task, :automate} => :task_automation
  }

  @type error ::
          :forbidden
          | :not_found
          | {:upgrade_required, %{feature: atom(), required_tier: String.t() | nil}}
          | {:subscription_inactive, String.t()}

  @spec authorize(Scope.t(), atom(), atom() | struct(), struct() | nil, keyword()) ::
          :ok | {:error, error()}
  def authorize(%Scope{} = scope, action, subject, record \\ nil, opts \\ []) do
    {type, record} = resolve(subject, record)
    role = Scope.role(scope)
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    with :ok <- check_tenant(scope, role, record),
         :ok <- check_role(role, type, action),
         :ok <- Policy.check(type, scope, action, record),
         :ok <- check_billing(scope, role, type, action, now) do
      check_entitlement(scope, role, type, action)
    end
  end

  @spec can?(Scope.t(), atom(), atom() | struct(), struct() | nil, keyword()) :: boolean()
  def can?(scope, action, subject, record \\ nil, opts \\ []) do
    authorize(scope, action, subject, record, opts) == :ok
  end

  @doc "Resource types and actions the requester's role allows, ignoring attributes and tier."
  @spec permissions(Scope.t()) :: %{atom() => [atom()]}
  def permissions(%Scope{} = scope), do: scope |> Scope.role() |> Permissions.for_role()

  defp resolve(type, nil) when is_atom(type), do: {type, nil}
  defp resolve(type, record) when is_atom(type), do: {type, record}
  defp resolve(%User{role: "client"} = user, nil), do: {:client, user}
  defp resolve(%User{} = user, nil), do: {:trainer, user}

  defp resolve(%module{} = record, nil) do
    case Map.fetch(@struct_types, module) do
      {:ok, type} -> {type, record}
      :error -> raise ArgumentError, "no authorization policy for #{inspect(module)}"
    end
  end

  defp check_tenant(_scope, :admin, _record), do: :ok
  defp check_tenant(_scope, _role, nil), do: :ok

  defp check_tenant(scope, _role, record) do
    if organization_id(record) == scope.user.organization_id, do: :ok, else: {:error, :not_found}
  end

  defp organization_id(%{organization_id: id}) when is_binary(id), do: id
  defp organization_id(%{client: %{organization_id: id}}) when is_binary(id), do: id

  defp organization_id(record) do
    raise ArgumentError,
          "cannot tell which organization #{inspect(record.__struct__)} belongs to; " <>
            "preload its :client"
  end

  defp check_role(role, type, action) do
    if Permissions.allowed?(role, type, action), do: :ok, else: {:error, :forbidden}
  end

  defp check_billing(_scope, :admin, _type, _action, _now), do: :ok
  defp check_billing(_scope, :client, _type, _action, _now), do: :ok
  defp check_billing(_scope, _role, :subscription, _action, _now), do: :ok

  defp check_billing(scope, _role, _type, action, now) do
    if Permissions.read_action?(action) or Entitlements.billing_state(scope, now) == :active do
      :ok
    else
      {:error, {:subscription_inactive, scope.subscription_status || scope.organization_status}}
    end
  end

  defp check_entitlement(_scope, :admin, _type, _action), do: :ok

  defp check_entitlement(scope, _role, :client, :create) do
    limit = Entitlements.client_limit(scope.tier)

    if limit == :infinity or scope.client_count < limit do
      :ok
    else
      {:error,
       {:upgrade_required,
        %{feature: :clients, required_tier: Entitlements.next_tier(scope.tier)}}}
    end
  end

  defp check_entitlement(scope, _role, type, action) do
    case gated_feature(type, action) do
      nil -> :ok
      feature -> require_feature(scope.tier, feature)
    end
  end

  defp gated_feature(type, action) do
    Map.get(@gated_actions, {type, action}) ||
      if not Permissions.read_action?(action), do: Map.get(@gated_writes, type)
  end

  defp require_feature(tier, feature) do
    if Entitlements.allows?(tier, feature) do
      :ok
    else
      {:error,
       {:upgrade_required,
        %{feature: feature, required_tier: Entitlements.required_tier(feature)}}}
    end
  end
end
