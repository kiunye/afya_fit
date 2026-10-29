defmodule AfyaFit.Authorization.Policy.WorkoutPlan do
  @moduledoc false
  @behaviour AfyaFit.Authorization.Policy

  alias AfyaFit.Authorization.Policy
  alias AfyaFit.Authorization.Scope

  @shared_actions [:list, :read, :duplicate]

  @impl true
  def check(scope, action, plan) do
    owner? = Scope.self?(scope, plan.trainer_id)

    Policy.allow?(owner? or (action in @shared_actions and (plan.is_public or plan.is_template)))
  end
end
