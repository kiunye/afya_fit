defmodule AfyaFitWeb.API.CalendarControllerTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Schedule

  setup do
    org = organization()

    %{
      org: org,
      trainer: user(org, :trainer),
      other: user(org, :trainer),
      client: user(org, :client)
    }
  end

  defp event!(org, owner, start_time) do
    {:ok, event} =
      Schedule.create_calendar_event(%{
        organization_id: org.id,
        user_id: owner.id,
        title: "Session",
        event_type: "appointment",
        start_time: start_time
      })

    event
  end

  defp soon, do: DateTime.utc_now() |> DateTime.add(2, :day) |> DateTime.truncate(:second)

  defp ids(conn), do: for(e <- json_response(conn, 200)["data"], do: e["id"])

  test "index and upcoming list only the requester's own events", %{
    conn: conn,
    org: org,
    trainer: trainer,
    other: other
  } do
    mine = event!(org, trainer, soon())
    theirs = event!(org, other, soon())
    conn = authenticate(conn, trainer)

    assert get(conn, ~p"/api/v1/calendar/events") |> ids() == [mine.id]
    assert get(conn, ~p"/api/v1/calendar/upcoming") |> ids() == [mine.id]
    refute theirs.id in ids(get(conn, ~p"/api/v1/calendar/events"))
  end

  test "an event is visible to its owner and org admin, not to other trainers", %{
    conn: conn,
    org: org,
    trainer: trainer,
    other: other
  } do
    event = event!(org, trainer, soon())

    assert conn
           |> authenticate(trainer)
           |> get(~p"/api/v1/calendar/events/#{event.id}")
           |> json_response(200)

    assert conn
           |> authenticate(user(org, :org_admin))
           |> get(~p"/api/v1/calendar/events/#{event.id}")
           |> json_response(200)

    assert conn
           |> authenticate(other)
           |> get(~p"/api/v1/calendar/events/#{event.id}")
           |> json_response(403)
  end

  test "another organization's event is not found", %{conn: conn, trainer: trainer} do
    foreign_org = organization()
    event = event!(foreign_org, user(foreign_org, :trainer), soon())

    assert conn
           |> authenticate(trainer)
           |> get(~p"/api/v1/calendar/events/#{event.id}")
           |> json_response(404)
  end

  test "owner updates without changing ownership, then deletes", %{
    conn: conn,
    org: org,
    trainer: trainer,
    other: other
  } do
    event = event!(org, trainer, soon())
    conn = authenticate(conn, trainer)

    body =
      put(conn, ~p"/api/v1/calendar/events/#{event.id}", %{
        "calendar_event" => %{"title" => "Renamed", "user_id" => other.id}
      })
      |> json_response(200)

    assert body["data"]["title"] == "Renamed"
    assert body["data"]["user_id"] == trainer.id
    assert delete(conn, ~p"/api/v1/calendar/events/#{event.id}") |> response(204)
  end

  test "another trainer cannot update or delete it", %{
    conn: conn,
    org: org,
    trainer: trainer,
    other: other
  } do
    event = event!(org, trainer, soon())
    conn = authenticate(conn, other)

    assert put(conn, ~p"/api/v1/calendar/events/#{event.id}", %{
             "calendar_event" => %{"title" => "X"}
           })
           |> json_response(403)

    assert delete(conn, ~p"/api/v1/calendar/events/#{event.id}") |> json_response(403)
  end

  describe "create" do
    @params %{
      "calendar_event" => %{
        "title" => "Check-in",
        "event_type" => "appointment",
        "start_time" => "2030-01-01T10:00:00Z"
      }
    }

    test "pro trainers create events", %{conn: conn, trainer: trainer} do
      assert conn
             |> authenticate(trainer)
             |> post(~p"/api/v1/calendar/events", @params)
             |> json_response(201)
    end

    test "the free tier needs an upgrade", %{conn: conn} do
      free_trainer = user(organization(%{plan_type: "free"}), :trainer)

      assert %{"error" => "upgrade_required", "feature" => "calendar"} =
               conn
               |> authenticate(free_trainer)
               |> post(~p"/api/v1/calendar/events", @params)
               |> json_response(402)
    end

    test "clients cannot create events", %{conn: conn, client: client} do
      assert conn
             |> authenticate(client)
             |> post(~p"/api/v1/calendar/events", @params)
             |> json_response(403)
    end
  end
end
