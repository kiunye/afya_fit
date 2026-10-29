defmodule AfyaFitWeb.TeamLiveTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias AfyaFit.Repo

  setup do
    org = organization()
    owner = user(org, :org_admin, %{first_name: "Wanjiru", last_name: "Njoroge"})
    trainer = user(org, :trainer, %{first_name: "Brian", last_name: "Kariuki"})
    link(trainer, user(org, :client))
    %{org: org, owner: owner, trainer: trainer}
  end

  test "trainers and clients cannot open the page", %{conn: conn, trainer: trainer, org: org} do
    for u <- [trainer, user(org, :client)] do
      {:ok, view, _} = conn |> log_in(u) |> live(~p"/team")
      assert has_element?(view, "#denied")
      refute has_element?(view, "#team")
    end
  end

  test "lists the owner and trainers with their client counts", %{
    conn: conn,
    owner: owner,
    trainer: trainer
  } do
    {:ok, view, _} = conn |> log_in(owner) |> live(~p"/team")

    assert has_element?(view, "#team", "2 trainers, you included")
    assert has_element?(view, "#members", "Wanjiru Njoroge")
    assert has_element?(view, "#members", "Owner")
    assert has_element?(view, "#members", "Brian Kariuki")
    assert has_element?(view, "#remove-#{trainer.id}")
    refute has_element?(view, "#remove-#{owner.id}")
  end

  test "adds a trainer and sends the password email", %{conn: conn, owner: owner} do
    {:ok, view, _} = conn |> log_in(owner) |> live(~p"/team")

    view |> element("#add-trainer") |> render_click()

    view
    |> form("#trainer-form",
      trainer: %{first_name: "Faith", last_name: "Chebet", email: "faith@example.com"}
    )
    |> render_submit()

    assert has_element?(view, "#members", "Faith Chebet")
    assert render(view) =~ "Trainer added"
    assert_email_sent(to: {"Faith Chebet", "faith@example.com"})
  end

  test "validation errors keep the form open", %{conn: conn, owner: owner} do
    {:ok, view, _} = conn |> log_in(owner) |> live(~p"/team")
    view |> element("#add-trainer") |> render_click()

    view |> form("#trainer-form", trainer: %{email: "nope"}) |> render_submit()

    assert has_element?(view, "#trainer-form")
  end

  test "removing a trainer asks first, then moves their clients to the owner", ctx do
    %{conn: conn, owner: owner, trainer: trainer} = ctx
    {:ok, view, _} = conn |> log_in(owner) |> live(~p"/team")

    view |> element("#remove-#{trainer.id}") |> render_click()
    assert has_element?(view, "#remove-confirm", "Remove Brian Kariuki?")
    assert has_element?(view, "#remove-confirm", "Their 1 clients")

    view |> element("#keep-trainer") |> render_click()
    refute has_element?(view, "#remove-confirm")

    view |> element("#remove-#{trainer.id}") |> render_click()
    view |> element("#confirm-remove") |> render_click()

    refute has_element?(view, "#members", "Brian Kariuki")
    assert render(view) =~ "Trainer removed. 1 client moved to you."
    assert Repo.reload!(trainer).deleted_at
  end

  test "a read-only account cannot add trainers", %{conn: conn, org: org, owner: owner} do
    subscription(org, %{status: "expired"})
    {:ok, view, _} = conn |> log_in(owner) |> live(~p"/team")

    view |> element("#add-trainer") |> render_click()

    assert render(view) =~ "Paused until payment clears"
    refute has_element?(view, "#trainer-form")
  end
end
