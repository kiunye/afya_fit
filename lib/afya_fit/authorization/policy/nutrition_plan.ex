defmodule AfyaFit.Authorization.Policy.NutritionPlan do
  @moduledoc false
  @behaviour AfyaFit.Authorization.Policy

  alias AfyaFit.Authorization.Policy
  alias AfyaFit.Authorization.Scope

  @impl true
  def check(scope, action, plan) do
    owner? = Scope.self?(scope, plan.trainer_id)
    readable? = owner? or plan.is_template or readable_by_client?(scope, plan)

    Policy.allow?(if(action in [:list, :read], do: readable?, else: owner?))
  end

  defp readable_by_client?(scope, plan) do
    Scope.manages_client?(scope, plan.client_id) or Scope.self?(scope, plan.client_id)
  end
end
