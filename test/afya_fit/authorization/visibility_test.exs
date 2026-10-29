defmodule AfyaFit.Authorization.VisibilityTest do
  @moduledoc """
  `Authorization.visible/2` (lists) and `Authorization.authorize/5` (single
  records) state the same attribute rules in two forms. This asserts they agree
  for every role, so a rule changed in one place cannot silently diverge.
  """
  use AfyaFit.DataCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Authorization
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.{Nutrition, Repo, Tasks, Workouts}

  setup do
    org = organization()
    owner = user(org, :org_admin)
    alice = user(org, :trainer)
    bob = user(org, :trainer)
    mine = user(org, :client)
    theirs = user(org, :client)
    loose = user(org, :client)
    link(alice, mine)
    link(bob, theirs)

    foreign_org = organization()
    foreign_trainer = user(foreign_org, :trainer)
    foreign_client = user(foreign_org, :client)

    plans =
      for {trainer, attrs} <- [
            {alice, %{name: "own"}},
            {bob, %{name: "private"}},
            {bob, %{name: "public", is_public: true}},
            {bob, %{name: "template", is_template: true}},
            {foreign_trainer, %{name: "foreign", is_public: true}}
          ] do
        {:ok, plan} =
          Workouts.create_workout_plan(
            Map.merge(%{organization_id: trainer.organization_id, trainer_id: trainer.id}, attrs)
          )

        plan
      end

    nutrition =
      for {trainer, client, attrs} <- [
            {alice, mine, %{name: "n-own"}},
            {bob, mine, %{name: "n-for-my-client"}},
            {bob, theirs, %{name: "n-theirs"}},
            {bob, loose, %{name: "n-template", is_template: true}},
            {foreign_trainer, foreign_client, %{name: "n-foreign"}}
          ] do
        {:ok, plan} =
          Nutrition.create_nutrition_plan(
            Map.merge(
              %{
                organization_id: trainer.organization_id,
                trainer_id: trainer.id,
                client_id: client.id,
                start_date: ~D[2026-01-01]
              },
              attrs
            )
          )

        plan
      end

    tasks =
      for {trainer, client, title} <- [
            {alice, mine, "t-own"},
            {bob, mine, "t-for-my-client"},
            {bob, theirs, "t-theirs"},
            {foreign_trainer, foreign_client, "t-foreign"}
          ] do
        {:ok, task} =
          Tasks.create_task(%{
            organization_id: trainer.organization_id,
            trainer_id: trainer.id,
            client_id: client.id,
            title: title,
            task_type: "custom",
            status: "pending"
          })

        task
      end

    %{
      plans: plans,
      nutrition: nutrition,
      tasks: tasks,
      clients: [mine, theirs, loose, foreign_client],
      actors: [
        platform_admin: user(org, :admin),
        org_admin: owner,
        trainer: alice,
        client: mine
      ]
    }
  end

  defp visible_ids(scope, type) do
    scope |> Authorization.visible(type) |> Repo.all() |> MapSet.new(& &1.id)
  end

  defp readable_ids(scope, records) do
    for record <- records,
        Authorization.authorize(scope, :read, record) == :ok,
        into: MapSet.new(),
        do: record.id
  end

  for type <- [:workout_plan, :nutrition_plan, :task] do
    test "lists and single-record checks agree for #{type}", ctx do
      key =
        case unquote(type) do
          :workout_plan -> :plans
          :nutrition_plan -> :nutrition
          :task -> :tasks
        end

      records = Map.fetch!(ctx, key)

      for {role, actor} <- ctx.actors do
        scope = Scope.load(actor)

        assert visible_ids(scope, unquote(type))
               |> MapSet.intersection(MapSet.new(records, & &1.id)) ==
                 readable_ids(scope, records),
               "#{unquote(type)}: visible and readable differ for #{role}"
      end
    end
  end

  test "lists and single-record checks agree for clients", %{clients: clients, actors: actors} do
    for {role, actor} <- actors do
      scope = Scope.load(actor)

      readable =
        for c <- clients,
            Authorization.authorize(scope, :read, c) == :ok,
            into: MapSet.new(),
            do: c.id

      visible =
        scope
        |> visible_ids(:client)
        |> MapSet.intersection(MapSet.new(clients, & &1.id))

      assert visible == readable, "client: visible and readable differ for #{role}"
    end
  end

  test "trainers do not see other trainers' private plans or foreign data", ctx do
    scope = Scope.load(ctx.actors[:trainer])
    names = scope |> Authorization.visible(:workout_plan) |> Repo.all() |> MapSet.new(& &1.name)

    assert names == MapSet.new(["own", "public", "template"])
  end
end
