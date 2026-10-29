defmodule AfyaFit.Authorization.Policy.ClientRecord do
  @moduledoc """
  Records that belong to a single client, such as assigned workouts and progress
  entries. Trainers reach their linked clients' records; clients reach their own.
  """
  @behaviour AfyaFit.Authorization.Policy

  alias AfyaFit.Authorization.Policy
  alias AfyaFit.Authorization.Scope

  @impl true
  def check(scope, _action, record) do
    Policy.allow?(
      Scope.manages_client?(scope, record.client_id) or Scope.self?(scope, record.client_id)
    )
  end
end
