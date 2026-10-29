defmodule AfyaFitWeb.ClientLive.HomeTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures
  import Phoenix.LiveViewTest

  alias AfyaFit.{Tasks, Workouts}

  setup do
    org = organization()
    trainer = user(org, :trainer)
    client = user(org, :client)
    link(trainer, client)
    %{org: org, trainer: trainer, client: client}
  end

  test "shows assigned workouts and open tasks", %{
    conn: conn,
    org: org,
    trainer: trainer,
    client: client
  } do
    {:ok, plan} =
      Workouts.create_workout_plan(%{
        name: "Lower body B",
        organization_id: org.id,
        trainer_id: trainer.id
      })

    {:ok, _} =
      Workouts.create_client_workout(%{
        client_id: client.id,
        workout_plan_id: plan.id,
        assigned_by: trainer.id,
        assigned_date: ~D[2026-10-01],
        start_date: ~D[2026-10-29],
        status: "assigned"
      })

    {:ok, _} =
      Tasks.create_task(%{
        organization_id: org.id,
        trainer_id: trainer.id,
        client_id: client.id,
        title: "Log your meals",
        task_type: "custom",
        status: "pending"
      })

    {:ok, view, _} = conn |> log_in(client) |> live(~p"/home")

    assert has_element?(view, "#workouts", "Lower body B")
    assert has_element?(view, "#tasks", "Log your meals")
  end

  test "nothing assigned says so", %{conn: conn, client: client} do
    {:ok, view, _} = conn |> log_in(client) |> live(~p"/home")

    assert has_element?(view, "#workouts-empty", "has not assigned a workout")
    assert has_element?(view, "#tasks-empty", "No tasks right now")
  end

  test "the landing page sends each role to where they work", %{
    conn: conn,
    org: org,
    trainer: trainer,
    client: client
  } do
    assert {:error, {:live_redirect, %{to: "/trainer/dashboard"}}} =
             conn |> log_in(trainer) |> live(~p"/")

    assert {:error, {:live_redirect, %{to: "/trainer/dashboard"}}} =
             conn |> log_in(user(org, :org_admin)) |> live(~p"/")

    assert {:error, {:live_redirect, %{to: "/home"}}} = conn |> log_in(client) |> live(~p"/")

    assert {:error, {:live_redirect, %{to: "/admin/dashboard"}}} =
             conn |> log_in(user(org, :admin)) |> live(~p"/")
  end

  test "visitors still see the landing page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Afya Fit"
  end
end
