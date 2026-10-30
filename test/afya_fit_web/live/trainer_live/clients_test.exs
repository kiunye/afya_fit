defmodule AfyaFitWeb.TrainerLive.ClientsTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures
  import Phoenix.LiveViewTest

  alias AfyaFit.Repo

  setup do
    org = organization()
    trainer = user(org, :trainer)
    mine = user(org, :client, %{first_name: "Otieno", last_name: "Odhiambo"})
    link(trainer, mine)

    %{
      org: org,
      trainer: trainer,
      mine: mine,
      stranger: user(org, :client, %{first_name: "Brian"})
    }
  end

  describe "index" do
    test "lists linked clients only", %{
      conn: conn,
      trainer: trainer,
      mine: mine,
      stranger: stranger
    } do
      {:ok, view, _html} = conn |> log_in(trainer) |> live(~p"/trainer/clients")

      assert has_element?(view, "#clients a[href='/trainer/clients/#{mine.id}']", "Open")
      refute has_element?(view, "#clients a[href='/trainer/clients/#{stranger.id}']")
    end

    test "an empty list says how to start", %{conn: conn, org: org} do
      lonely = user(org, :trainer)
      {:ok, view, _} = conn |> log_in(lonely) |> live(~p"/trainer/clients")

      assert has_element?(view, "#clients-empty", "Add your first client")
    end

    test "the status filter lives in the URL", %{conn: conn, trainer: trainer, mine: mine} do
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/clients?status=archived")

      refute has_element?(view, "#clients a[href='/trainer/clients/#{mine.id}']")
      assert has_element?(view, "#clients-empty", "No archived clients")
    end

    test "clients cannot open the page", %{conn: conn, mine: mine} do
      {:ok, view, _} = conn |> log_in(mine) |> live(~p"/trainer/clients")
      assert has_element?(view, "#denied")
    end
  end

  describe "archiving" do
    test "asks first, then moves the client out of the list", ctx do
      %{conn: conn, trainer: trainer, mine: mine} = ctx
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/clients")

      view |> element("#archive-#{mine.id}") |> render_click()
      assert has_element?(view, "#archive-confirm", "Archive Otieno Odhiambo?")

      view |> element("#keep-client") |> render_click()
      refute has_element?(view, "#archive-confirm")
      assert has_element?(view, "#clients a[href='/trainer/clients/#{mine.id}']")

      view |> element("#archive-#{mine.id}") |> render_click()
      view |> element("#confirm-archive") |> render_click()

      assert render(view) =~ "Otieno archived."
      refute has_element?(view, "#clients a[href='/trainer/clients/#{mine.id}']")

      assert Repo.get_by!(AfyaFit.Accounts.TrainerClient, client_id: mine.id).status ==
               "archived"
    end

    test "archived clients can be restored from their filter", ctx do
      %{conn: conn, trainer: trainer, mine: mine} = ctx

      {:ok, _} =
        AfyaFit.Clients.archive_client_links(mine, AfyaFit.Authorization.Scope.load(trainer))

      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/clients?status=archived")
      refute has_element?(view, "#archive-#{mine.id}")

      view |> element("#restore-#{mine.id}") |> render_click()

      assert render(view) =~ "Client restored."
      refute has_element?(view, "#restore-#{mine.id}")

      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/clients")
      assert has_element?(view, "#clients a[href='/trainer/clients/#{mine.id}']")
    end

    test "someone else's client cannot be archived by id", ctx do
      %{conn: conn, trainer: trainer, stranger: stranger} = ctx
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/clients")

      render_hook(view, "ask_archive", %{"id" => stranger.id})

      refute has_element?(view, "#archive-confirm")
      assert has_element?(view, "#flash-error")
    end

    test "restoring into a full Free plan opens the limit dialog", %{conn: conn} do
      org = organization(%{plan_type: "free"})
      trainer = user(org, :trainer)
      gone = user(org, :client)
      link(trainer, gone, "archived")
      for _ <- 1..3, do: link(trainer, user(org, :client))

      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/clients?status=archived")
      view |> element("#restore-#{gone.id}") |> render_click()

      assert has_element?(view, "#limit-dialog")
    end
  end

  describe "the Free plan limit" do
    setup do
      org = organization(%{plan_type: "free"})
      owner = user(org, :org_admin, %{first_name: "Wanjiru", last_name: "Njoroge"})
      trainer = user(org, :trainer)
      for _ <- 1..3, do: link(trainer, user(org, :client))
      %{free_org: org, owner: owner, free_trainer: trainer}
    end

    test "Add client opens the limit dialog instead of the form", %{
      conn: conn,
      free_trainer: trainer
    } do
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/clients")

      view |> element("#add-client") |> render_click()

      assert has_element?(view, "#limit-dialog", "Client limit reached")
      assert has_element?(view, "#limit-dialog", "3 clients")
      assert has_element?(view, "#limit-dialog", "25 clients")
      assert has_element?(view, "#limit-dialog", "Ask Wanjiru Njoroge (owner) to upgrade")
      refute has_element?(view, "#limit-dialog a", "Upgrade to Pro")
    end

    test "the owner gets the upgrade action and can dismiss the dialog", %{
      conn: conn,
      owner: owner
    } do
      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/trainer/clients")
      view |> element("#add-client") |> render_click()

      assert has_element?(view, "#limit-dialog a[href='/billing']", "Upgrade to Pro")

      view |> element("#limit-dialog button", "Not now") |> render_click()
      refute has_element?(view, "#limit-dialog")
    end

    test "opening the new-client URL directly redirects to the list with the dialog", %{
      conn: conn,
      free_trainer: trainer
    } do
      conn = log_in(conn, trainer)

      assert {:error, {:live_redirect, %{to: "/trainer/clients?limit=1"}}} =
               live(conn, ~p"/trainer/clients/new")

      {:ok, view, _} = live(conn, ~p"/trainer/clients?limit=1")
      assert has_element?(view, "#limit-dialog", "Client limit reached")
    end
  end

  describe "a read-only account" do
    test "keeps Add client visible but unavailable, with the reason", %{
      conn: conn,
      org: org,
      trainer: trainer
    } do
      subscription(org, %{status: "cancelled"})
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/clients")

      assert has_element?(view, "#add-client[aria-disabled=true]", "Add client")
      assert render(view) =~ "Paused until payment clears"
    end
  end

  describe "new, show and edit" do
    test "creates a client and returns to the list", %{conn: conn, trainer: trainer} do
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/clients/new")

      {:ok, _view, html} =
        view
        |> form("#client-form",
          client: %{
            first_name: "Amina",
            last_name: "Hassan",
            email: "amina@example.com",
            password: "a-long-enough-password"
          }
        )
        |> render_submit()
        |> follow_redirect(conn |> log_in(trainer), ~p"/trainer/clients")

      assert html =~ "Client added."
    end

    test "shows a linked client and refuses an unlinked one", %{
      conn: conn,
      trainer: trainer,
      mine: mine,
      stranger: stranger
    } do
      conn = log_in(conn, trainer)

      {:ok, view, _} = live(conn, ~p"/trainer/clients/#{mine.id}")
      assert has_element?(view, "h1", "Otieno Odhiambo")

      {:ok, view, _} = live(conn, ~p"/trainer/clients/#{stranger.id}")
      assert has_element?(view, "#denied")
    end

    test "another organisation's client is not found", %{conn: conn, trainer: trainer} do
      foreign = user(organization(), :client)
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/clients/#{foreign.id}")

      assert has_element?(view, "#denied", "Not found")
    end

    test "a garbage id is not found rather than a crash", %{conn: conn, trainer: trainer} do
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/clients/not-a-uuid")
      assert has_element?(view, "#denied", "Not found")
    end

    test "Nutrition is a closed sign on Free", %{conn: conn} do
      org = organization(%{plan_type: "free"})
      trainer = user(org, :trainer)
      client = user(org, :client)
      link(trainer, client)

      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/clients/#{client.id}")
      assert has_element?(view, "#client-nutrition", "Nutrition plans")
      assert has_element?(view, "#client-nutrition", "Pro")
    end

    test "editing ignores role and organisation changes", %{
      conn: conn,
      trainer: trainer,
      mine: mine
    } do
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/clients/#{mine.id}/edit")

      view
      |> element("#client-form")
      |> render_submit(%{client: %{first_name: "Renamed", role: "admin"}})

      reloaded = Repo.reload!(mine)
      assert reloaded.first_name == "Renamed"
      assert reloaded.role == "client"
    end
  end
end
