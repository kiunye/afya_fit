defmodule AfyaFit.ClientsArchiveTest do
  use AfyaFit.DataCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Accounts.TrainerClient
  alias AfyaFit.Authorization
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Clients
  alias AfyaFit.Repo

  setup do
    org = organization(%{plan_type: "free"})
    owner = user(org, :org_admin)
    trainer = user(org, :trainer)
    client = user(org, :client)
    link(trainer, client)

    %{org: org, owner: owner, trainer: trainer, client: client}
  end

  defp scope(user), do: Scope.load(user)

  defp archive!(client, by), do: {:ok, _} = Clients.archive_client_links(client, scope(by))

  describe "who counts as archived" do
    test "a client is archived when every link is, not before", ctx do
      %{org: org, trainer: trainer, client: client} = ctx
      other = user(org, :trainer)
      link(other, client)

      archive!(client, trainer)
      refute scope(client).archived

      archive!(client, other)
      assert scope(client).archived
    end

    test "a client who was never linked is not archived", %{org: org} do
      refute org |> user(:client) |> scope() |> Map.fetch!(:archived)
    end

    test "archiving frees a place on the plan", ctx do
      %{owner: owner, trainer: trainer, client: client} = ctx
      assert scope(owner).client_count == 1

      archive!(client, trainer)
      assert scope(owner).client_count == 0
    end
  end

  describe "listing for an organization admin" do
    test "archived clients leave the default list and have their own filter", ctx do
      %{owner: owner, trainer: trainer, client: client} = ctx
      active = user(ctx.org, :client)
      link(trainer, active)
      archive!(client, trainer)

      assert [%{id: id}] = Clients.list_clients_for(scope(owner))
      assert id == active.id
      assert [%{id: archived_id}] = Clients.list_clients_for(scope(owner), %{status: "archived"})
      assert archived_id == client.id
    end
  end

  describe "restore_client/2" do
    test "a trainer restores their own link", %{trainer: trainer, client: client} do
      archive!(client, trainer)

      assert {:ok, %TrainerClient{status: "active", ended_at: nil}} =
               Clients.restore_client(scope(trainer), client.id)

      refute scope(client).archived
    end

    test "an organization admin restores the most recent link", ctx do
      %{owner: owner, trainer: trainer, client: client} = ctx
      archive!(client, trainer)

      assert {:ok, %TrainerClient{trainer_id: trainer_id}} =
               Clients.restore_client(scope(owner), client.id)

      assert trainer_id == trainer.id
    end

    test "another trainer cannot restore it", %{org: org, trainer: trainer, client: client} do
      archive!(client, trainer)

      assert {:error, :not_found} = Clients.restore_client(scope(user(org, :trainer)), client.id)
    end

    test "another organization's client is not found", %{trainer: trainer, client: client} do
      archive!(client, trainer)
      stranger = user(organization(), :org_admin)

      assert {:error, :not_found} = Clients.restore_client(scope(stranger), client.id)
    end

    test "a malformed id is not found", %{trainer: trainer} do
      assert {:error, :not_found} = Clients.restore_client(scope(trainer), "nope")
    end

    test "the client limit applies: a full Free plan cannot take one back", ctx do
      %{org: org, trainer: trainer, client: client} = ctx
      archive!(client, trainer)
      for _ <- 1..3, do: link(trainer, user(org, :client))

      assert {:error, {:upgrade_required, %{feature: :clients}}} =
               Clients.restore_client(scope(trainer), client.id)
    end
  end

  describe "an archived client's own data" do
    setup %{trainer: trainer, client: client} do
      archive!(client, trainer)
      %{scope: scope(client)}
    end

    test "can be read", %{scope: scope} do
      assert :ok = Authorization.authorize(scope, :list, :client_workout)
      assert :ok = Authorization.authorize(scope, :read, :nutrition_plan)
    end

    test "cannot be changed", %{scope: scope} do
      assert {:error, :archived} = Authorization.authorize(scope, :complete, :client_workout)
      assert {:error, :archived} = Authorization.authorize(scope, :create, :progress_entry)
    end

    test "is advertised as read-only in the access payload", %{scope: scope} do
      permissions = Authorization.permissions(scope)

      assert permissions[:client] == [:read]
      assert :complete not in permissions[:client_workout]
    end

    test "an active client keeps every permission", %{org: org, trainer: trainer} do
      active = user(org, :client)
      link(trainer, active)

      assert :ok = Authorization.authorize(scope(active), :complete, :client_workout)
    end
  end

  test "restoring writes the status to the database", %{trainer: trainer, client: client} do
    archive!(client, trainer)
    {:ok, _} = Clients.restore_client(scope(trainer), client.id)

    assert Repo.get_by!(TrainerClient, trainer_id: trainer.id, client_id: client.id).status ==
             "active"
  end
end
