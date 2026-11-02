defmodule AfyaFit.Authorization.ScopeQueriesTest do
  use AfyaFit.DataCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Accounts.TrainerClient
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Repo

  setup do
    org = organization(%{plan_type: "pro"})
    owner = user(org, :org_admin, %{first_name: "Wanjiru", last_name: "Njoroge"})
    trainer = user(org, :trainer)
    client = user(org, :client)
    link(trainer, client)
    %{org: org, owner: owner, trainer: trainer, client: client}
  end

  # How many times `Scope.load/1` goes to the database for this user.
  defp queries(user) do
    test = self()
    id = {__MODULE__, make_ref()}

    :telemetry.attach(
      id,
      [:afya_fit, :repo, :query],
      fn _event, _measurements, _metadata, _config ->
        if self() == test, do: send(test, :query)
      end,
      nil
    )

    Scope.load(user)
    :telemetry.detach(id)

    count_messages(0)
  end

  defp count_messages(n) do
    receive do
      :query -> count_messages(n + 1)
    after
      0 -> n
    end
  end

  describe "how much a scope costs to load" do
    test "a client needs the organization, its plan and their own links", %{client: client} do
      assert queries(client) == 3
    end

    test "an owner also needs the owner's name and the client count", %{owner: owner} do
      assert queries(owner) == 4
    end

    test "a trainer also needs the clients they reach", %{trainer: trainer} do
      assert queries(trainer) == 5
    end
  end

  describe "what a client does not carry" do
    test "the organisation-wide figures only coaches use", %{client: client, owner: owner} do
      client_scope = Scope.load(client)
      owner_scope = Scope.load(owner)

      assert client_scope.client_count == 0
      assert client_scope.owner_name == nil
      assert owner_scope.client_count == 1
      assert owner_scope.owner_name == "Wanjiru Njoroge"
    end

    test "but still knows the plan and whether coaching has ended", %{
      client: client,
      trainer: trainer
    } do
      assert %Scope{tier: "pro", archived: false} = Scope.load(client)

      {:ok, _} = AfyaFit.Clients.archive_client_links(client, Scope.load(trainer))

      assert %Scope{archived: true} = Scope.load(client)
    end
  end

  describe "TrainerClient.ended?/1 agrees with the query behind client counts" do
    test "for every mix of link states", %{org: org, trainer: trainer} do
      other = user(org, :trainer)

      combos = [
        [],
        ["active"],
        ["paused"],
        ["archived"],
        ["archived", "archived"],
        ["archived", "active"],
        ["archived", "paused"]
      ]

      for statuses <- combos do
        client = user(org, :client)

        statuses
        |> Enum.zip([trainer, other])
        |> Enum.each(fn {status, coach} -> link(coach, client, status) end)

        in_sql = client.id in Repo.all(TrainerClient.archived_client_ids())

        assert TrainerClient.ended?(statuses) == in_sql, inspect(statuses)
      end
    end
  end
end
