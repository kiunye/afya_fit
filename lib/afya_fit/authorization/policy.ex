defmodule AfyaFit.Authorization.Policy do
  @moduledoc """
  Attribute-based rules, evaluated per resource once the role allows the action.

  Each resource has a policy module that states its rules twice, side by side:
  `check/3` decides whether the scope may act on one loaded record, and
  `visible/1` returns the query of every record the scope may see. They share
  the helpers below so the two cannot drift apart.

  Platform admins and organization admins pass every attribute rule in
  `check/3`: tenant isolation has already been enforced and `Permissions`
  already limits what they may do.
  """

  import Ecto.Query, only: [where: 3]

  alias AfyaFit.Authorization.Policy
  alias AfyaFit.Authorization.Scope

  @callback check(Scope.t(), atom(), struct()) :: :ok | {:error, :forbidden}
  @callback visible(Scope.t()) :: Ecto.Query.t()
  @optional_callbacks visible: 1

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

  # Only the resources that are listed have a `visible/1`.
  @visible %{
    client: Policy.Person,
    workout_plan: Policy.WorkoutPlan,
    nutrition_plan: Policy.NutritionPlan,
    task: Policy.Task
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

  @doc "The query of every `type` record the scope may see."
  @spec visible(atom(), Scope.t()) :: Ecto.Query.t()
  def visible(type, %Scope{} = scope), do: Map.fetch!(@visible, type).visible(scope)

  @doc false
  @spec allow?(boolean()) :: :ok | {:error, :forbidden}
  def allow?(true), do: :ok
  def allow?(_), do: {:error, :forbidden}

  ## Helpers shared by the policies' `visible/1`

  @doc "Restricts a query to the scope's organization; platform admins see every organization."
  def tenant(query, %Scope{} = scope) do
    if Scope.role(scope) == :admin,
      do: query,
      else: where(query, [r], r.organization_id == ^scope.user.organization_id)
  end

  @doc "A query that matches nothing, for roles with no access to a resource."
  def none(query), do: where(query, [r], false)

  @doc "The ids of the clients a trainer coaches."
  def linked_client_ids(%Scope{client_ids: ids}), do: MapSet.to_list(ids)
end
