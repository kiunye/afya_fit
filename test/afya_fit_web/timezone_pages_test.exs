defmodule AfyaFitWeb.TimezonePagesTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures
  import Phoenix.LiveViewTest

  alias AfyaFit.Accounts.User
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.{Repo, Schedule, Today}
  alias AfyaFit.Workers.TaskReminderWorker

  setup do
    org = organization()
    %{org: org, trainer: user(org, :trainer, %{first_name: "Wanjiru"})}
  end

  describe "the browser's zone" do
    test "is adopted on the first connected page for someone on UTC", ctx do
      %{conn: conn, trainer: trainer} = ctx

      conn
      |> log_in(trainer)
      |> put_connect_params(%{"timezone" => "Africa/Nairobi"})
      |> live(~p"/trainer/dashboard")

      assert Repo.get!(User, trainer.id).timezone == "Africa/Nairobi"
    end

    test "does not replace a zone the person chose", %{conn: conn, org: org} do
      chosen = user(org, :trainer, %{timezone: "Europe/London"})

      conn
      |> log_in(chosen)
      |> put_connect_params(%{"timezone" => "Africa/Nairobi"})
      |> live(~p"/trainer/dashboard")

      assert Repo.get!(User, chosen.id).timezone == "Europe/London"
    end
  end

  describe "settings" do
    test "the time zone can be changed", %{conn: conn, trainer: trainer} do
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/users/settings")

      view
      |> form("#timezone_form", user: %{timezone: "Africa/Lagos"})
      |> render_submit()

      assert render(view) =~ "Time zone saved."
      assert Repo.get!(User, trainer.id).timezone == "Africa/Lagos"
    end
  end

  describe "Today" do
    setup %{org: org, trainer: trainer} do
      {:ok, _} =
        Repo.update(Ecto.Changeset.change(trainer, timezone: "Africa/Nairobi"))

      # 21:30 UTC on the 30th is half past midnight on the 31st in Nairobi.
      {:ok, _event} =
        Schedule.create_calendar_event(%{
          organization_id: org.id,
          user_id: trainer.id,
          title: "Late session",
          event_type: "appointment",
          start_time: ~U[2026-10-30 21:30:00Z]
        })

      %{trainer: Repo.get!(User, trainer.id)}
    end

    test "belongs to the day it falls on for the viewer", %{trainer: trainer} do
      scope = Scope.load(trainer)

      assert %{sessions: []} = Today.build(scope, ~U[2026-10-30 12:00:00Z])

      assert %{sessions: [%{title: "Late session", time: ~T[00:30:00]}]} =
               Today.build(scope, ~U[2026-10-30 22:00:00Z])
    end

    test "the page says which day it is where the viewer is", %{conn: conn, trainer: trainer} do
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/dashboard")

      today = AfyaFit.Timezone.today("Africa/Nairobi")
      assert has_element?(view, "#today", Calendar.strftime(today, "%a %-d %b"))
    end
  end

  describe "calendar API" do
    test "a time without an offset is the creator's wall clock", %{conn: conn, org: org} do
      nairobi = user(org, :trainer, %{timezone: "Africa/Nairobi"})

      conn =
        conn
        |> authenticate(nairobi)
        |> post(~p"/api/v1/calendar/events", %{
          "calendar_event" => %{
            "title" => "Check-in",
            "event_type" => "appointment",
            "start_time" => "2030-01-01T10:00:00"
          }
        })

      assert %{"data" => %{"start_time" => start_time, "timezone" => "Africa/Nairobi"}} =
               json_response(conn, 201)

      assert start_time =~ "2030-01-01T07:00:00"
    end

    test "a time with an offset is taken as given", %{conn: conn, org: org} do
      nairobi = user(org, :trainer, %{timezone: "Africa/Nairobi"})

      conn =
        conn
        |> authenticate(nairobi)
        |> post(~p"/api/v1/calendar/events", %{
          "calendar_event" => %{
            "title" => "Check-in",
            "event_type" => "appointment",
            "start_time" => "2030-01-01T10:00:00Z"
          }
        })

      assert %{"data" => %{"start_time" => start_time}} = json_response(conn, 201)
      assert start_time =~ "2030-01-01T10:00:00"
    end
  end

  describe "task reminders" do
    test "are due on the client's today and tomorrow, not UTC's" do
      client = %User{timezone: "Africa/Nairobi"}
      now = ~U[2026-10-30 21:30:00Z]

      # Nairobi is already on the 31st: due 1 Nov 00:30 local is tomorrow,
      # due 2 Nov 00:30 local is two days away.
      tomorrow = %{client: client, due_date: ~U[2026-10-31 21:30:00Z]}
      two_days = %{client: client, due_date: ~U[2026-11-01 21:30:00Z]}
      yesterday = %{client: client, due_date: ~U[2026-10-29 12:00:00Z]}

      assert TaskReminderWorker.due_soon?(struct(AfyaFit.Tasks.Task, tomorrow), now)
      refute TaskReminderWorker.due_soon?(struct(AfyaFit.Tasks.Task, two_days), now)
      refute TaskReminderWorker.due_soon?(struct(AfyaFit.Tasks.Task, yesterday), now)
    end
  end
end
