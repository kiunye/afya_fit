defmodule AfyaFit.TodayTest do
  use AfyaFit.DataCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Authorization.Scope
  alias AfyaFit.{Schedule, Tasks, Tracking, Workouts}
  alias AfyaFit.Today

  @now ~U[2026-10-29 11:10:00Z]

  setup do
    org = organization()
    trainer = user(org, :trainer, %{first_name: "Wanjiru", last_name: "Njoroge"})
    client = user(org, :client, %{first_name: "Otieno", last_name: "Odhiambo"})
    link(trainer, client)
    %{org: org, trainer: trainer, client: client}
  end

  defp plan!(org, trainer) do
    {:ok, plan} =
      Workouts.create_workout_plan(%{
        name: "Lower body B",
        organization_id: org.id,
        trainer_id: trainer.id
      })

    plan
  end

  defp assign_workout!(trainer, client, plan, attrs) do
    {:ok, cw} =
      Workouts.create_client_workout(
        Map.merge(
          %{
            client_id: client.id,
            workout_plan_id: plan.id,
            assigned_by: trainer.id,
            assigned_date: ~D[2026-10-01],
            start_date: ~D[2026-10-29],
            status: "assigned"
          },
          attrs
        )
      )

    cw
  end

  describe "sessions" do
    test "on any plan: workouts starting today for reachable clients, done ones marked", ctx do
      %{org: org, trainer: trainer, client: client} = ctx
      plan = plan!(org, trainer)
      assign_workout!(trainer, client, plan, %{})
      other = user(org, :client)
      assign_workout!(trainer, other, plan, %{})

      today = Today.build(Scope.load(trainer), @now)

      assert [%{kind: :workout, title: "Otieno Odhiambo", detail: "Lower body B", state: :next}] =
               today.sessions
    end

    test "a completed workout is done and the first open one is next", ctx do
      %{org: org, trainer: trainer, client: client} = ctx
      plan = plan!(org, trainer)
      second = user(org, :client, %{first_name: "Amina", last_name: "Hassan"})
      link(trainer, second)

      assign_workout!(trainer, client, plan, %{status: "completed"})
      assign_workout!(trainer, second, plan, %{})

      states = Today.build(Scope.load(trainer), @now).sessions |> Enum.map(&{&1.title, &1.state})

      assert {"Otieno Odhiambo", :done} in states
      assert {"Amina Hassan", :next} in states
    end

    test "calendar events today appear with their time when the plan includes the calendar",
         ctx do
      %{org: org, trainer: trainer} = ctx

      {:ok, _} =
        Schedule.create_calendar_event(%{
          organization_id: org.id,
          user_id: trainer.id,
          title: "Check-in call",
          event_type: "appointment",
          start_time: ~U[2026-10-29 12:30:00Z]
        })

      assert [%{kind: :event, title: "Check-in call", time: ~T[12:30:00]}] =
               Today.build(Scope.load(trainer), @now).sessions
    end

    test "free organisations do not list calendar events", ctx do
      free = organization(%{plan_type: "free"})
      trainer = user(free, :trainer)

      {:ok, _} =
        Schedule.create_calendar_event(%{
          organization_id: free.id,
          user_id: trainer.id,
          title: "Check-in call",
          event_type: "appointment",
          start_time: ~U[2026-10-29 12:30:00Z]
        })

      assert [] = Today.build(Scope.load(trainer), @now).sessions
      assert ctx.org
    end
  end

  describe "needs you" do
    test "overdue tasks are grouped per client", %{org: org, trainer: trainer, client: client} do
      for title <- ["A", "B"] do
        {:ok, _} =
          Tasks.create_task(%{
            organization_id: org.id,
            trainer_id: trainer.id,
            client_id: client.id,
            title: title,
            task_type: "custom",
            status: "pending",
            due_date: ~U[2026-10-27 08:00:00Z]
          })
      end

      assert [%{client: %{id: id}, reason: reason, overdue: true}] =
               Today.build(Scope.load(trainer), @now).needs_you

      assert id == client.id
      assert reason =~ "2 tasks overdue"
    end

    test "a progress entry from the last three days is surfaced with the change", ctx do
      %{trainer: trainer, client: client} = ctx

      for {date, weight} <- [{~D[2026-10-08], 69.5}, {~D[2026-10-28], 68.4}] do
        {:ok, _} =
          Tracking.create_progress_entry(%{
            client_id: client.id,
            trainer_id: trainer.id,
            entry_date: date,
            weight: weight
          })
      end

      assert [%{reason: reason, overdue: false}] =
               Today.build(Scope.load(trainer), @now).needs_you

      assert reason =~ "68.4 kg"
      assert reason =~ "down 1.1"
    end

    test "other organisations' and unlinked clients never appear", ctx do
      %{org: org, trainer: trainer} = ctx
      stranger = user(org, :client)

      {:ok, _} =
        Tasks.create_task(%{
          organization_id: org.id,
          trainer_id: trainer.id,
          client_id: stranger.id,
          title: "X",
          task_type: "custom",
          status: "pending",
          due_date: ~U[2026-10-20 08:00:00Z]
        })

      assert [] = Today.build(Scope.load(trainer), @now).needs_you
    end
  end

  test "the summary line counts what is done and what is left", ctx do
    %{org: org, trainer: trainer, client: client} = ctx
    plan = plan!(org, trainer)
    assign_workout!(trainer, client, plan, %{status: "completed"})
    second = user(org, :client)
    link(trainer, second)
    assign_workout!(trainer, second, plan, %{})

    assert %{done: 1, remaining: 1} = Today.build(Scope.load(trainer), @now).counts
  end

  test "org admins see every client's items in the organisation", ctx do
    %{org: org, trainer: trainer, client: client} = ctx
    plan = plan!(org, trainer)
    assign_workout!(trainer, client, plan, %{})
    admin = user(org, :org_admin)

    assert [%{title: "Otieno Odhiambo"}] = Today.build(Scope.load(admin), @now).sessions
  end
end
