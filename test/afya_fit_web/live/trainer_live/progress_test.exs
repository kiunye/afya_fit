defmodule AfyaFitWeb.TrainerLive.ProgressTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures
  import Phoenix.LiveViewTest

  alias AfyaFit.Tracking

  setup do
    org = organization()
    trainer = user(org, :trainer)
    client = user(org, :client, %{first_name: "Amina", last_name: "Hassan"})
    link(trainer, client)
    %{org: org, trainer: trainer, client: client, stranger: user(org, :client)}
  end

  defp entry!(trainer, client, date, weight, body_fat \\ nil) do
    {:ok, entry} =
      Tracking.create_progress_entry(%{
        client_id: client.id,
        trainer_id: trainer.id,
        entry_date: date,
        weight: weight,
        body_fat_percentage: body_fat
      })

    entry
  end

  describe "index" do
    test "lists the clients the trainer coaches", %{
      conn: conn,
      trainer: trainer,
      client: client,
      stranger: stranger
    } do
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/progress")

      assert has_element?(view, "#clients a[href='/trainer/progress/#{client.id}']")
      refute has_element?(view, "#clients a[href='/trainer/progress/#{stranger.id}']")
    end

    test "an empty list says how to start", %{conn: conn, org: org} do
      {:ok, view, _} = conn |> log_in(user(org, :trainer)) |> live(~p"/trainer/progress")
      assert has_element?(view, "#clients-empty", "No clients yet")
    end
  end

  describe "a client's progress" do
    test "shows entries newest first with the weight change", %{
      conn: conn,
      trainer: trainer,
      client: client
    } do
      entry!(trainer, client, ~D[2026-10-08], 69.5, 24.0)
      entry!(trainer, client, ~D[2026-10-28], 68.4, 23.1)

      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/progress/#{client.id}")

      assert has_element?(view, "h1", "Amina Hassan")
      assert has_element?(view, "#entries", "68.4 kg")
      assert has_element?(view, "#weight-change", "-1.1 kg")
      assert has_element?(view, "#body-fat-change", "-0.9 %")
    end

    test "no entries yet", %{conn: conn, trainer: trainer, client: client} do
      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/progress/#{client.id}")
      assert has_element?(view, "#entries-empty", "No entries yet")
    end

    test "an unlinked client is refused; another organisation's is not found", %{
      conn: conn,
      trainer: trainer,
      stranger: stranger
    } do
      conn = log_in(conn, trainer)

      {:ok, view, _} = live(conn, ~p"/trainer/progress/#{stranger.id}")
      assert has_element?(view, "#denied")

      foreign = user(organization(), :client)
      {:ok, view, _} = live(conn, ~p"/trainer/progress/#{foreign.id}")
      assert has_element?(view, "#denied", "Not found")

      {:ok, view, _} = live(conn, ~p"/trainer/progress/nope")
      assert has_element?(view, "#denied", "Not found")
    end

    test "a client can open their own page", %{conn: conn, trainer: trainer, client: client} do
      entry!(trainer, client, ~D[2026-10-28], 68.4)
      {:ok, view, _} = conn |> log_in(client) |> live(~p"/trainer/progress/#{client.id}")
      assert has_element?(view, "#entries", "68.4 kg")
    end
  end

  describe "analytics on the Free plan" do
    test "are a closed sign; entries stay readable", %{conn: conn} do
      org = organization(%{plan_type: "free"})
      owner = user(org, :org_admin, %{first_name: "Wanjiru", last_name: "Njoroge"})
      trainer = user(org, :trainer)
      client = user(org, :client)
      link(trainer, client)
      entry!(trainer, client, ~D[2026-10-28], 68.4)

      {:ok, view, _} = conn |> log_in(trainer) |> live(~p"/trainer/progress/#{client.id}")

      assert has_element?(view, "#analytics-closed", "Analytics")
      assert has_element?(view, "#analytics-closed", "Ask Wanjiru Njoroge (owner) to upgrade")
      refute has_element?(view, "#weight-change")
      assert has_element?(view, "#entries", "68.4 kg")
      assert owner
    end
  end
end
