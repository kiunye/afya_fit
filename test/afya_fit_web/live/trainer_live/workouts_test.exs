defmodule AfyaFitWeb.TrainerLive.WorkoutsTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures
  import Phoenix.LiveViewTest

  alias AfyaFit.{Repo, Workouts}
  alias AfyaFit.Workouts.WorkoutPlan

  setup do
    org = organization()
    trainer = user(org, :trainer)
    other = user(org, :trainer)
    %{org: org, trainer: trainer, other: other}
  end

  defp plan!(org, trainer, attrs \\ %{}) do
    {:ok, plan} =
      Workouts.create_workout_plan(
        Map.merge(
          %{
            name: "Plan",
            organization_id: org.id,
            trainer_id: trainer.id,
            duration_weeks: 6,
            difficulty: "beginner"
          },
          attrs
        )
      )

    plan
  end

  describe "index" do
    test "tabs split mine, shared and templates", ctx do
      %{conn: conn, org: org, trainer: trainer, other: other} = ctx
      mine = plan!(org, trainer, %{name: "Mine A"})
      shared = plan!(org, other, %{name: "Shared B", is_public: true})
      template = plan!(org, other, %{name: "Template C", is_template: true})
      hidden = plan!(org, other, %{name: "Hidden D"})
      conn = log_in(conn, trainer)

      {:ok, view, _} = live(conn, ~p"/trainer/workouts")
      assert has_element?(view, "#plans", mine.name)
      refute has_element?(view, "#plans", shared.name)

      {:ok, view, _} = live(conn, ~p"/trainer/workouts?tab=shared")
      assert has_element?(view, "#plans", shared.name)

      {:ok, view, _} = live(conn, ~p"/trainer/workouts?tab=templates")
      assert has_element?(view, "#plans", template.name)

      for tab <- ["mine", "shared", "templates"] do
        {:ok, view, _} = live(conn, ~p"/trainer/workouts?tab=#{tab}")
        refute has_element?(view, "#plans", hidden.name)
      end
    end

    test "an empty library says how to start", %{conn: conn, trainer: trainer} do
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/workouts")
      assert has_element?(view, "#plans-empty", "No workout plans yet")
    end

    test "clients cannot open the page", %{conn: conn, org: org} do
      {:ok, view, _} = conn |> log_in(user(org, :client)) |> live(~p"/trainer/workouts")
      assert has_element?(view, "#denied")
    end

    test "a read-only account keeps New plan visible but paused", %{
      conn: conn,
      org: org,
      trainer: trainer
    } do
      subscription(org, %{status: "cancelled"})
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/workouts")

      assert has_element?(view, "#new-plan[aria-disabled=true]")
      assert render(view) =~ "Paused until payment clears"
    end
  end

  describe "access to a single plan" do
    test "another trainer's private plan is refused, even by direct URL", ctx do
      %{conn: conn, org: org, trainer: trainer, other: other} = ctx
      private = plan!(org, other)
      conn = log_in(conn, trainer)

      for path <- [~p"/trainer/workouts/#{private.id}", ~p"/trainer/workouts/#{private.id}/edit"] do
        {:ok, view, _} = live(conn, path)
        assert has_element?(view, "#denied")
      end
    end

    test "a plan in another organisation is not found", %{conn: conn, trainer: trainer} do
      foreign_org = organization()
      foreign = plan!(foreign_org, user(foreign_org, :trainer), %{is_public: true})

      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/workouts/#{foreign.id}")
      assert has_element?(view, "#denied", "Not found")
    end

    test "a shared plan can be read and duplicated but not edited", ctx do
      %{conn: conn, org: org, trainer: trainer, other: other} = ctx
      shared = plan!(org, other, %{is_public: true, name: "Shared"})
      conn = log_in(conn, trainer)

      {:ok, view, _} = live(conn, ~p"/trainer/workouts/#{shared.id}")
      assert has_element?(view, "h1", "Shared")
      refute has_element?(view, "#edit-plan")
      refute has_element?(view, "#delete-plan")

      view |> element("#duplicate-plan") |> render_click()
      assert Repo.get_by!(WorkoutPlan, name: "Shared (Copy)").trainer_id == trainer.id

      {:ok, view, _} = live(conn, ~p"/trainer/workouts/#{shared.id}/edit")
      assert has_element?(view, "#denied")
    end

    test "garbage ids are not found", %{conn: conn, trainer: trainer} do
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/workouts/nope")
      assert has_element?(view, "#denied", "Not found")
    end
  end

  describe "create, update and delete" do
    test "creates a plan owned by the trainer", %{conn: conn, org: org, trainer: trainer} do
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/workouts/new")

      view
      |> element("#workout-form")
      |> render_submit(%{
        workout_plan: %{
          name: "Strength",
          duration_weeks: "8",
          difficulty: "advanced",
          trainer_id: Ecto.UUID.generate(),
          organization_id: Ecto.UUID.generate()
        }
      })

      plan = Repo.get_by!(WorkoutPlan, name: "Strength")
      assert plan.trainer_id == trainer.id
      assert plan.organization_id == org.id
    end

    test "invalid input keeps the form", %{conn: conn, trainer: trainer} do
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/workouts/new")
      html = view |> element("#workout-form") |> render_submit(%{workout_plan: %{name: ""}})
      assert html =~ "workout-form"
    end

    test "the owner edits; ownership fields are ignored", ctx do
      %{conn: conn, org: org, trainer: trainer} = ctx
      plan = plan!(org, trainer)
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/workouts/#{plan.id}/edit")

      view
      |> element("#workout-form")
      |> render_submit(%{workout_plan: %{name: "Renamed", trainer_id: Ecto.UUID.generate()}})

      reloaded = Repo.reload!(plan)
      assert reloaded.name == "Renamed"
      assert reloaded.trainer_id == trainer.id
    end

    test "deleting asks first and names the plan", %{conn: conn, org: org, trainer: trainer} do
      plan = plan!(org, trainer, %{name: "Lower body B"})
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/workouts/#{plan.id}")

      view |> element("#ask-delete") |> render_click()
      assert has_element?(view, "#delete-confirm", "Delete Lower body B?")

      view |> element("#keep-plan") |> render_click()
      refute has_element?(view, "#delete-confirm")

      view |> element("#ask-delete") |> render_click()
      view |> element("#confirm-delete") |> render_click()
      assert Repo.get(WorkoutPlan, plan.id) == nil
    end

    test "org admins can edit any plan in the organisation", ctx do
      %{conn: conn, org: org, other: other} = ctx
      plan = plan!(org, other)
      admin = user(org, :org_admin)

      {:ok, view, _} = conn |> log_in(admin) |> live(~p"/trainer/workouts/#{plan.id}/edit")
      assert has_element?(view, "#workout-form")
    end
  end
end
