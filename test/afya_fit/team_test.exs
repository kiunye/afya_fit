defmodule AfyaFit.TeamTest do
  use AfyaFit.DataCase, async: true

  import AfyaFitWeb.APIFixtures
  import Swoosh.TestAssertions

  alias AfyaFit.Accounts
  alias AfyaFit.Accounts.TrainerClient
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Shared.ActivityLog
  alias AfyaFit.{Nutrition, Repo, Tasks, Team, Workouts}

  setup do
    org = organization()
    admin = user(org, :org_admin, %{first_name: "Wanjiru", last_name: "Njoroge"})
    trainer = user(org, :trainer, %{first_name: "Brian", last_name: "Kariuki"})
    %{org: org, admin: admin, trainer: trainer, scope: Scope.load(admin)}
  end

  defp url_fun, do: fn token -> "https://example.test/users/reset_password/#{token}" end

  describe "list_members/1" do
    test "owner first, with client counts, never other organisations or removed people", ctx do
      %{org: org, trainer: trainer, scope: scope} = ctx
      link(trainer, user(org, :client))
      link(trainer, user(org, :client), "archived")
      _foreign = user(organization(), :trainer)

      assert [%{user: %{role: "org_admin"}, client_count: 0}, %{user: member, client_count: 1}] =
               Team.list_members(scope)

      assert member.id == trainer.id
    end
  end

  describe "invite_trainer/3" do
    test "creates a trainer in the organisation and emails a password link", %{
      scope: scope,
      org: org
    } do
      params = %{"email" => "faith@example.com", "first_name" => "Faith", "last_name" => "Chebet"}

      assert {:ok, trainer} = Team.invite_trainer(scope, params, url_fun())

      assert trainer.role == "trainer"
      assert trainer.organization_id == org.id
      assert_email_sent(to: {"Faith Chebet", "faith@example.com"})
      assert Repo.get_by(ActivityLog, action: "trainer.invited", resource_id: trainer.id)
    end

    test "ignores role and organisation in the params", %{scope: scope} do
      other = organization()

      params = %{
        "email" => "x@example.com",
        "first_name" => "X",
        "last_name" => "Y",
        "role" => "admin",
        "organization_id" => other.id
      }

      assert {:ok, trainer} = Team.invite_trainer(scope, params, url_fun())
      assert trainer.role == "trainer"
      assert trainer.organization_id == scope.user.organization_id
    end

    test "reports invalid details as a changeset", %{scope: scope} do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Team.invite_trainer(scope, %{"email" => "nope"}, url_fun())

      assert %{email: _, first_name: _} = errors_on(changeset)
    end

    test "only organisation admins can add trainers", %{trainer: trainer} do
      assert {:error, :forbidden} =
               Team.invite_trainer(Scope.load(trainer), %{"email" => "a@b.co"}, url_fun())
    end

    test "a read-only organisation cannot add trainers", %{org: org, admin: admin} do
      subscription(org, %{status: "expired"})

      assert {:error, {:subscription_inactive, _}} =
               Team.invite_trainer(Scope.load(admin), %{"email" => "a@b.co"}, url_fun())
    end
  end

  describe "remove_trainer/2" do
    setup %{org: org, trainer: trainer, admin: admin} do
      client = user(org, :client)
      shared = user(org, :client)
      link(trainer, client)
      link(trainer, shared)
      link(admin, shared)

      {:ok, plan} =
        Workouts.create_workout_plan(%{
          name: "Plan",
          organization_id: org.id,
          trainer_id: trainer.id
        })

      {:ok, task} =
        Tasks.create_task(%{
          organization_id: org.id,
          trainer_id: trainer.id,
          client_id: client.id,
          title: "T",
          task_type: "custom",
          status: "pending"
        })

      {:ok, nutrition} =
        Nutrition.create_nutrition_plan(%{
          name: "N",
          organization_id: org.id,
          trainer_id: trainer.id,
          client_id: client.id,
          start_date: ~D[2026-01-01]
        })

      %{client: client, shared: shared, plan: plan, task: task, nutrition: nutrition}
    end

    test "moves clients and owned records to the admin and ends access", ctx do
      %{
        scope: scope,
        trainer: trainer,
        admin: admin,
        client: client,
        plan: plan,
        task: task,
        nutrition: nutrition
      } = ctx

      token = Accounts.generate_user_session_token(trainer)

      assert {:ok, %{clients_moved: 2}} = Team.remove_trainer(scope, trainer.id)

      assert Repo.get_by!(TrainerClient, client_id: client.id).trainer_id == admin.id
      assert Repo.reload!(plan).trainer_id == admin.id
      assert Repo.reload!(task).trainer_id == admin.id
      assert Repo.reload!(nutrition).trainer_id == admin.id
      assert Repo.reload!(trainer).deleted_at

      assert Accounts.get_user_by_session_token(token) == nil
      refute Accounts.get_user_by_email_and_password(trainer.email, "anything")
      assert [%{user: %{id: id}}] = Team.list_members(scope)
      assert id == admin.id
    end

    test "a client the admin already coaches keeps one link", %{
      scope: scope,
      trainer: trainer,
      shared: shared
    } do
      assert {:ok, _} = Team.remove_trainer(scope, trainer.id)
      assert [_one] = Repo.all(from tc in TrainerClient, where: tc.client_id == ^shared.id)
    end

    test "is recorded in the activity log", %{scope: scope, trainer: trainer, admin: admin} do
      assert {:ok, _} = Team.remove_trainer(scope, trainer.id)

      log = Repo.get_by!(ActivityLog, action: "trainer.removed", resource_id: trainer.id)
      assert log.user_id == admin.id
      assert log.metadata["clients_moved"] == 2
    end

    test "the owner cannot be removed, and neither can people in other organisations", ctx do
      %{scope: scope, admin: admin} = ctx
      assert {:error, :forbidden} = Team.remove_trainer(scope, admin.id)

      foreign = user(organization(), :trainer)
      assert {:error, :not_found} = Team.remove_trainer(scope, foreign.id)
    end

    test "trainers cannot remove each other", %{org: org, trainer: trainer} do
      other = user(org, :trainer)
      assert {:error, :forbidden} = Team.remove_trainer(Scope.load(trainer), other.id)
    end
  end
end
