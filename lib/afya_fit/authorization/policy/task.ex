defmodule AfyaFit.Authorization.Policy.Task do
  @moduledoc false
  @behaviour AfyaFit.Authorization.Policy

  alias AfyaFit.Authorization.Policy
  alias AfyaFit.Authorization.Scope

  @impl true
  def check(scope, _action, task) do
    Policy.allow?(
      Scope.self?(scope, task.trainer_id) or
        Scope.manages_client?(scope, task.client_id) or
        Scope.self?(scope, task.client_id)
    )
  end
end
