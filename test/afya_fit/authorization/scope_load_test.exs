defmodule AfyaFit.Authorization.ScopeLoadTest do
  use AfyaFit.DataCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Authorization.Scope

  setup do
    org = organization(%{plan_type: "free"})
    %{org: org, trainer: user(org, :trainer)}
  end

  test "loads the organization, tier and linked clients", %{org: org, trainer: trainer} do
    client = user(org, :client)
    link(trainer, client)
    link(trainer, user(org, :client), "archived")

    scope = Scope.load(trainer)

    assert scope.organization.id == org.id
    assert scope.tier == "free"
    assert MapSet.to_list(scope.client_ids) == [client.id]
    assert scope.client_count == 2
  end

  test "reads subscription status and period end", %{org: org, trainer: trainer} do
    subscription(org, %{status: "past_due"})

    scope = Scope.load(trainer)

    assert scope.subscription_status == "past_due"
    assert %DateTime{} = scope.period_end
  end

  test "organization admins reach every client without links", %{org: org} do
    admin = user(org, :org_admin)
    client = user(org, :client)

    scope = Scope.load(admin)

    assert Scope.manages_client?(scope, client.id)
    assert scope.client_ids == MapSet.new()
  end
end
