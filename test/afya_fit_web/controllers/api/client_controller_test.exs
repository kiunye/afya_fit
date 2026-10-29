defmodule AfyaFitWeb.API.ClientControllerTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Accounts.TrainerClient
  alias AfyaFit.Repo

  setup do
    org = organization()
    trainer = user(org, :trainer)
    mine = user(org, :client)
    link(trainer, mine)
    %{org: org, trainer: trainer, mine: mine, stranger: user(org, :client)}
  end

  defp ids(conn), do: for(c <- json_response(conn, 200)["data"], do: c["id"])

  describe "index" do
    test "a trainer lists only linked clients", %{
      conn: conn,
      trainer: trainer,
      mine: mine,
      stranger: stranger
    } do
      listed = conn |> authenticate(trainer) |> get(~p"/api/v1/clients") |> ids()
      assert listed == [mine.id]
      refute stranger.id in listed
    end

    test "an org admin lists every client in the organization", %{
      conn: conn,
      org: org,
      mine: mine,
      stranger: stranger
    } do
      listed = conn |> authenticate(user(org, :org_admin)) |> get(~p"/api/v1/clients") |> ids()
      assert Enum.sort(listed) == Enum.sort([mine.id, stranger.id])
    end

    test "clients are forbidden", %{conn: conn, mine: mine} do
      assert conn |> authenticate(mine) |> get(~p"/api/v1/clients") |> json_response(403)
    end
  end

  describe "show" do
    test "linked client is readable", %{conn: conn, trainer: trainer, mine: mine} do
      assert %{"data" => %{"id" => id}} =
               conn
               |> authenticate(trainer)
               |> get(~p"/api/v1/clients/#{mine.id}")
               |> json_response(200)

      assert id == mine.id
    end

    test "an unlinked client in the same organization is forbidden", %{
      conn: conn,
      trainer: trainer,
      stranger: stranger
    } do
      assert conn
             |> authenticate(trainer)
             |> get(~p"/api/v1/clients/#{stranger.id}")
             |> json_response(403)
    end

    test "a client in another organization is not found", %{conn: conn, trainer: trainer} do
      other_org = organization()
      foreign = user(other_org, :client)

      assert conn
             |> authenticate(trainer)
             |> get(~p"/api/v1/clients/#{foreign.id}")
             |> json_response(404)
    end

    test "a paused link still grants access", %{conn: conn, trainer: trainer, stranger: stranger} do
      link(trainer, stranger, "paused")

      assert conn
             |> authenticate(trainer)
             |> get(~p"/api/v1/clients/#{stranger.id}")
             |> json_response(200)
    end
  end

  describe "create" do
    @params %{
      "client" => %{
        "email" => "new@example.com",
        "password" => "a-long-enough-password",
        "first_name" => "N",
        "last_name" => "C"
      }
    }

    test "creates and links a client", %{conn: conn, trainer: trainer} do
      assert %{"data" => %{"email" => "new@example.com"}} =
               conn
               |> authenticate(trainer)
               |> post(~p"/api/v1/clients", @params)
               |> json_response(201)
    end

    test "the free tier stops at three clients", %{conn: conn} do
      org = organization(%{plan_type: "free"})
      trainer = user(org, :trainer)
      for _ <- 1..3, do: link(trainer, user(org, :client))

      body =
        conn |> authenticate(trainer) |> post(~p"/api/v1/clients", @params) |> json_response(402)

      assert %{"error" => "upgrade_required", "feature" => "clients", "required_tier" => "pro"} =
               body
    end

    test "clients are forbidden", %{conn: conn, mine: mine} do
      assert conn
             |> authenticate(mine)
             |> post(~p"/api/v1/clients", @params)
             |> json_response(403)
    end
  end

  describe "update" do
    test "updates a linked client but ignores privileged fields", %{
      conn: conn,
      trainer: trainer,
      mine: mine
    } do
      other_org = organization()

      body =
        conn
        |> authenticate(trainer)
        |> put(~p"/api/v1/clients/#{mine.id}", %{
          "client" => %{
            "first_name" => "Renamed",
            "role" => "admin",
            "organization_id" => other_org.id
          }
        })
        |> json_response(200)

      assert body["data"]["first_name"] == "Renamed"
      assert body["data"]["organization_id"] == mine.organization_id
      assert Repo.reload!(mine).role == "client"
    end

    test "an unlinked client cannot be updated", %{
      conn: conn,
      trainer: trainer,
      stranger: stranger
    } do
      conn =
        conn
        |> authenticate(trainer)
        |> put(~p"/api/v1/clients/#{stranger.id}", %{"client" => %{"first_name" => "X"}})

      assert json_response(conn, 403)
    end
  end

  describe "delete and invite" do
    test "archives the trainer-client link", %{conn: conn, trainer: trainer, mine: mine} do
      assert conn
             |> authenticate(trainer)
             |> delete(~p"/api/v1/clients/#{mine.id}")
             |> response(204)

      assert Repo.get_by!(TrainerClient, trainer_id: trainer.id, client_id: mine.id).status ==
               "archived"
    end

    test "an org admin can archive every link of a client", %{
      conn: conn,
      org: org,
      trainer: trainer,
      mine: mine
    } do
      assert conn
             |> authenticate(user(org, :org_admin))
             |> delete(~p"/api/v1/clients/#{mine.id}")
             |> response(204)

      assert Repo.get_by!(TrainerClient, trainer_id: trainer.id, client_id: mine.id).status ==
               "archived"
    end

    test "an unlinked client cannot be removed or invited", %{
      conn: conn,
      trainer: trainer,
      stranger: stranger
    } do
      conn = authenticate(conn, trainer)
      assert conn |> delete(~p"/api/v1/clients/#{stranger.id}") |> json_response(403)
      assert conn |> post(~p"/api/v1/clients/#{stranger.id}/invite") |> json_response(403)
    end

    test "invite works for a linked client", %{conn: conn, trainer: trainer, mine: mine} do
      assert conn
             |> authenticate(trainer)
             |> post(~p"/api/v1/clients/#{mine.id}/invite")
             |> json_response(200)
    end
  end
end
