defmodule AfyaFit.Authorization.Policy.WorkoutPlan do
  @moduledoc false
  @behaviour AfyaFit.Authorization.Policy

  import Ecto.Query

  alias AfyaFit.Authorization.Policy
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Workouts.WorkoutPlan

  @shared_actions [:list, :read, :duplicate]

  @impl true
  def check(scope, action, plan) do
    owner? = Scope.self?(scope, plan.trainer_id)

    Policy.allow?(owner? or (action in @shared_actions and (plan.is_public or plan.is_template)))
  end

  @impl true
  def visible(scope) do
    plans = Policy.tenant(WorkoutPlan, scope)

    case Scope.role(scope) do
      role when role in [:admin, :org_admin] ->
        plans

      :trainer ->
        where(plans, [p], p.trainer_id == ^scope.user.id or p.is_public or p.is_template)

      _ ->
        Policy.none(plans)
    end
  end
end
