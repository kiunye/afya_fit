defmodule AfyaFitWeb.TrainerLive.NutritionTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures
  import Phoenix.LiveViewTest

  alias AfyaFit.{Nutrition, Repo}
  alias AfyaFit.Nutrition.NutritionPlan

  setup do
    org = organization()
    trainer = user(org, :trainer)
    client = user(org, :client, %{first_name: "Amina", last_name: "Hassan"})
    link(trainer, client)

    %{
      org: org,
      trainer: trainer,
      client: client,
      other: user(org, :trainer),
      stranger: user(org, :client)
    }
  end

  defp plan!(org, trainer, client, attrs \\ %{}) do
    {:ok, plan} =
      Nutrition.create_nutrition_plan(
        Map.merge(
          %{
            name: "Cut",
            organization_id: org.id,
            trainer_id: trainer.id,
            client_id: client.id,
            start_date: ~D[2026-10-01],
            daily_calories: 2100
          },
          attrs
        )
      )

    plan
  end

  describe "on Pro" do
    test "lists plans the trainer can read", %{
      conn: conn,
      org: org,
      trainer: trainer,
      client: client,
      other: other,
      stranger: stranger
    } do
      mine = plan!(org, trainer, client, %{name: "Mine"})
      hidden = plan!(org, other, stranger, %{name: "Hidden"})

      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/nutrition")

      assert has_element?(view, "#plans", mine.name)
      refute has_element?(view, "#plans", hidden.name)
      assert has_element?(view, "#new-plan", "New plan")
      refute has_element?(view, "#nutrition-closed")
    end

    test "creates a plan for a linked client, as the trainer", %{
      conn: conn,
      org: org,
      trainer: trainer,
      client: client
    } do
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/nutrition/new")

      view
      |> element("#nutrition-form")
      |> render_submit(%{
        nutrition_plan: %{
          name: "Bulk",
          client_id: client.id,
          start_date: "2026-11-01",
          daily_calories: "2800",
          trainer_id: Ecto.UUID.generate()
        }
      })

      plan = Repo.get_by!(NutritionPlan, name: "Bulk")
      assert plan.trainer_id == trainer.id
      assert plan.organization_id == org.id
    end

    test "refuses a client the trainer does not coach", %{
      conn: conn,
      trainer: trainer,
      stranger: stranger
    } do
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/nutrition/new")

      html =
        view
        |> element("#nutrition-form")
        |> render_submit(%{
          nutrition_plan: %{name: "Sneaky", client_id: stranger.id, start_date: "2026-11-01"}
        })

      assert html =~ "is not one of your clients"
      assert Repo.get_by(NutritionPlan, name: "Sneaky") == nil
    end

    test "another trainer's plan is refused by direct URL", %{
      conn: conn,
      org: org,
      trainer: trainer,
      other: other,
      stranger: stranger
    } do
      theirs = plan!(org, other, stranger)

      for path <- [~p"/trainer/nutrition/#{theirs.id}", ~p"/trainer/nutrition/#{theirs.id}/edit"] do
        {:ok, view, _} = conn |> log_in(trainer) |> live(path)
        assert has_element?(view, "#denied")
      end
    end

    test "shows a plan with its client, and deleting asks first", %{
      conn: conn,
      org: org,
      trainer: trainer,
      client: client
    } do
      plan = plan!(org, trainer, client, %{name: "Cut"})
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/nutrition/#{plan.id}")

      assert has_element?(view, "li", "Amina Hassan")

      view |> element("#ask-delete") |> render_click()
      assert has_element?(view, "#delete-confirm", "Delete Cut?")
      view |> element("#confirm-delete") |> render_click()
      assert Repo.get(NutritionPlan, plan.id) == nil
    end

    test "a client reads their own plan but cannot edit it", %{
      conn: conn,
      org: org,
      trainer: trainer,
      client: client
    } do
      plan = plan!(org, trainer, client)

      {:ok, view, _} = conn |> log_in(client) |> live(~p"/trainer/nutrition")
      assert has_element?(view, "#plans", plan.name)
      refute has_element?(view, "#new-plan")

      {:ok, view, _} = conn |> log_in(client) |> live(~p"/trainer/nutrition/#{plan.id}/edit")
      assert has_element?(view, "#denied")
    end
  end

  describe "on the Free plan" do
    setup do
      org = organization(%{plan_type: "free"})
      owner = user(org, :org_admin, %{first_name: "Wanjiru", last_name: "Njoroge"})
      trainer = user(org, :trainer)
      client = user(org, :client)
      link(trainer, client)
      %{free: org, owner: owner, free_trainer: trainer, free_client: client}
    end

    test "creating is a closed sign naming who can upgrade; existing plans stay readable", ctx do
      %{conn: conn, free: org, free_trainer: trainer, free_client: client} = ctx
      existing = plan!(org, trainer, client, %{name: "Old plan"})

      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/nutrition")

      assert has_element?(view, "#nutrition-closed", "Nutrition plans")
      assert has_element?(view, "#nutrition-closed", "Ask Wanjiru Njoroge (owner) to upgrade")
      refute has_element?(view, "#new-plan")
      assert has_element?(view, "#plans", existing.name)
    end

    test "the owner gets the upgrade action", %{conn: conn, owner: owner} do
      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/trainer/nutrition")
      assert has_element?(view, "#nutrition-closed a[href='/billing']", "Upgrade to Pro")
    end

    test "the new-plan URL goes back to the list", %{conn: conn, free_trainer: trainer} do
      assert {:error, {:live_redirect, %{to: "/trainer/nutrition"}}} =
               conn |> log_in(trainer) |> live(~p"/trainer/nutrition/new")
    end
  end
end
