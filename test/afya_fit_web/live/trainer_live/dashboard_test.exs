defmodule AfyaFitWeb.TrainerLive.DashboardTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures
  import Phoenix.LiveViewTest

  alias AfyaFit.{Tasks, Workouts}

  setup do
    org = organization()
    trainer = user(org, :trainer, %{first_name: "Wanjiru", last_name: "Njoroge"})
    client = user(org, :client, %{first_name: "Otieno", last_name: "Odhiambo"})
    link(trainer, client)
    %{org: org, trainer: trainer, client: client}
  end

  test "redirects visitors to log in", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, ~p"/trainer/dashboard")
  end

  test "shows the day's sessions and who needs the trainer", ctx do
    %{conn: conn, org: org, trainer: trainer, client: client} = ctx

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
        assigned_date: Date.utc_today(),
        start_date: Date.utc_today(),
        status: "assigned"
      })

    {:ok, _} =
      Tasks.create_task(%{
        organization_id: org.id,
        trainer_id: trainer.id,
        client_id: client.id,
        title: "Log meals",
        task_type: "custom",
        status: "pending",
        due_date: DateTime.add(DateTime.utc_now(), -2, :day)
      })

    {:ok, view, html} = conn |> log_in(trainer) |> live(~p"/trainer/dashboard")

    assert html =~ "Otieno Odhiambo"
    assert has_element?(view, "#sessions .sign, #sessions div", "Lower body B")
    assert has_element?(view, "#needs", "1 task overdue")
    assert has_element?(view, "#needs a[href='/trainer/clients/#{client.id}']")
  end

  test "an empty day says what to do next", %{conn: conn, trainer: trainer} do
    {:ok, view, _html} = conn |> log_in(trainer) |> live(~p"/trainer/dashboard")

    assert has_element?(view, "#sessions-empty", "Nothing scheduled today")
    assert has_element?(view, "#needs-empty", "Nobody needs you")
  end

  test "the free plan shows Calendar as a closed sign naming who can upgrade" do
    free = organization(%{plan_type: "free"})
    owner = user(free, :org_admin, %{first_name: "Wanjiru", last_name: "Njoroge"})
    trainer = user(free, :trainer)

    {:ok, view, _} = build_conn() |> log_in(trainer) |> live(~p"/trainer/dashboard")
    assert has_element?(view, "#calendar-closed", "Calendar")
    assert has_element?(view, "#calendar-closed", "Ask Wanjiru Njoroge (owner) to upgrade")
    refute has_element?(view, "#calendar-closed a", "Upgrade to Pro")

    {:ok, view, _} = build_conn() |> log_in(owner) |> live(~p"/trainer/dashboard")
    assert has_element?(view, "#calendar-closed a[href='/billing']", "Upgrade to Pro")
  end

  test "clients get a permission sign instead of the page", %{conn: conn, client: client} do
    {:ok, view, _html} = conn |> log_in(client) |> live(~p"/trainer/dashboard")

    assert has_element?(view, "#denied", "Not for your role")
    refute has_element?(view, "#today")
  end
end
