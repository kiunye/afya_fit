defmodule AfyaFitWeb.PlanBlockHooksTest do
  @moduledoc "A 402 on the API, or a limit dialog on the web, is recorded for support."
  use AfyaFitWeb.ConnCase, async: true
  use Oban.Testing, repo: AfyaFit.Repo

  import AfyaFitWeb.APIFixtures
  import Phoenix.LiveViewTest

  alias AfyaFit.Workers.PlanBlockedWorker

  setup do
    org = organization(%{plan_type: "free"})
    %{org: org, trainer: user(org, :trainer)}
  end

  test "the API records a plan limit when it answers 402", %{
    conn: conn,
    org: org,
    trainer: trainer
  } do
    params = %{"nutrition_plan" => %{"name" => "Cut"}}

    assert conn
           |> authenticate(trainer)
           |> post(~p"/api/v1/nutrition-plans", params)
           |> json_response(402)

    assert_enqueued(
      worker: PlanBlockedWorker,
      args: %{kind: "upgrade_required", feature: "nutrition_plans", organization_id: org.id}
    )
  end

  test "the API records a read-only account when it answers 402", %{
    conn: conn,
    org: org,
    trainer: trainer
  } do
    subscription(org, %{status: "cancelled"})
    params = %{"workout_plan" => %{"name" => "Blocked"}}

    assert conn
           |> authenticate(trainer)
           |> post(~p"/api/v1/workout-plans", params)
           |> json_response(402)

    assert_enqueued(
      worker: PlanBlockedWorker,
      args: %{kind: "subscription_inactive", feature: "read_only"}
    )
  end

  test "plain refusals are not recorded", %{conn: conn, org: org} do
    assert conn
           |> authenticate(user(org, :client))
           |> get(~p"/api/v1/workout-plans")
           |> json_response(403)

    refute_enqueued(worker: PlanBlockedWorker)
  end

  test "the web limit dialog is recorded when it opens, not when the page loads", %{
    conn: conn,
    org: org,
    trainer: trainer
  } do
    for _ <- 1..3, do: link(trainer, user(org, :client))
    {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/clients")

    refute_enqueued(worker: PlanBlockedWorker)

    view |> element("#add-client") |> render_click()

    assert_enqueued(
      worker: PlanBlockedWorker,
      args: %{feature: "clients", organization_id: org.id}
    )
  end
end
