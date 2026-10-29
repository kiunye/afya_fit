defmodule AfyaFit.Authorization.Policy.NutritionPlan do
  @moduledoc false
  @behaviour AfyaFit.Authorization.Policy

  import Ecto.Query

  alias AfyaFit.Authorization.Policy
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Nutrition.NutritionPlan

  @impl true
  def check(scope, action, plan) do
    owner? = Scope.self?(scope, plan.trainer_id)
    readable? = owner? or coach_template?(scope, plan) or readable_by_client?(scope, plan)

    Policy.allow?(if(action in [:list, :read], do: readable?, else: owner?))
  end

  # Templates are for coaches; clients only see plans assigned to them.
  defp coach_template?(scope, plan), do: plan.is_template and Scope.role(scope) != :client

  defp readable_by_client?(scope, plan) do
    Scope.manages_client?(scope, plan.client_id) or Scope.self?(scope, plan.client_id)
  end

  @impl true
  def visible(scope) do
    plans = Policy.tenant(NutritionPlan, scope)

    case Scope.role(scope) do
      role when role in [:admin, :org_admin] ->
        plans

      :trainer ->
        client_ids = Policy.linked_client_ids(scope)

        where(
          plans,
          [p],
          p.trainer_id == ^scope.user.id or p.is_template or p.client_id in ^client_ids
        )

      :client ->
        where(plans, [p], p.client_id == ^scope.user.id)

      _ ->
        Policy.none(plans)
    end
  end
end
