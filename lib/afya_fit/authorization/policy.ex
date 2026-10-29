defmodule AfyaFit.Authorization.Policy do
  @moduledoc """
  Attribute-based rules, evaluated per resource once the role allows the action.

  Each resource has a policy module implementing `check/3`. Platform admins and
  organization admins pass every attribute rule: tenant isolation has already
  been enforced and `Permissions` already limits what they may do.
  """

  alias AfyaFit.Authorization.Policy
  alias AfyaFit.Authorization.Scope

  @callback check(Scope.t(), atom(), struct()) :: :ok | {:error, :forbidden}

  @policies %{
    client: Policy.Person,
    trainer: Policy.Person,
    workout_plan: Policy.WorkoutPlan,
    client_workout: Policy.ClientRecord,
    progress_entry: Policy.ClientRecord,
    nutrition_plan: Policy.NutritionPlan,
    task: Policy.Task,
    calendar_event: Policy.CalendarEvent,
    client_subscription: Policy.ClientSubscription
  }

  @spec check(atom(), Scope.t(), atom(), struct() | nil) :: :ok | {:error, :forbidden}
  def check(_type, _scope, _action, nil), do: :ok

  def check(type, scope, action, record) do
    if Scope.role(scope) in [:admin, :org_admin] do
      :ok
    else
      case Map.fetch(@policies, type) do
        {:ok, policy} -> policy.check(scope, action, record)
        :error -> {:error, :forbidden}
      end
    end
  end

  @doc false
  @spec allow?(boolean()) :: :ok | {:error, :forbidden}
  def allow?(true), do: :ok
  def allow?(_), do: {:error, :forbidden}
end
