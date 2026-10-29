defmodule AfyaFit.Authorization.Policy.Person do
  @moduledoc false
  @behaviour AfyaFit.Authorization.Policy

  alias AfyaFit.Authorization.Policy
  alias AfyaFit.Authorization.Scope

  @impl true
  def check(scope, _action, record) do
    Policy.allow?(
      case Scope.role(scope) do
        :trainer -> Scope.manages_client?(scope, record.id)
        :client -> Scope.self?(scope, record.id)
        _ -> false
      end
    )
  end
end
