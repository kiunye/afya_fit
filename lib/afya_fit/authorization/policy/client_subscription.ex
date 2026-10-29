defmodule AfyaFit.Authorization.Policy.ClientSubscription do
  @moduledoc false
  @behaviour AfyaFit.Authorization.Policy

  alias AfyaFit.Authorization.Policy
  alias AfyaFit.Authorization.Scope

  @impl true
  def check(scope, _action, subscription) do
    Policy.allow?(Scope.self?(scope, subscription.client_id))
  end
end
