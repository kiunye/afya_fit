defmodule AfyaFitWeb.LayoutsTest do
  use ExUnit.Case, async: true

  import AfyaFit.AuthorizationFixtures
  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias AfyaFitWeb.Layouts

  defp render_app(scope, active \\ :clients) do
    assigns = %{scope: scope, active: active}

    rendered_to_string(~H"""
    <Layouts.app flash={%{}} current_scope={@scope} active={@active}>
      <p id="page-content">Hello</p>
    </Layouts.app>
    """)
  end

  defp query(html, selector), do: html |> LazyHTML.from_fragment() |> LazyHTML.query(selector)

  defp texts(html, selector),
    do: html |> query(selector) |> Enum.map(&String.trim(LazyHTML.text(&1)))

  test "renders the page inside the shell with a skip link and the main landmark" do
    html = render_app(scope(:trainer))

    assert [_] = Enum.to_list(query(html, "main#main #page-content"))
    assert [_] = Enum.to_list(query(html, "a[href='#main']"))
  end

  test "marks the current page in the sidebar" do
    html = render_app(scope(:trainer), :workouts)

    assert ["Workouts"] = texts(html, "#sidebar a[aria-current=page]")
  end

  test "org admins see Team and Billing, trainers do not" do
    admin = render_app(scope(:org_admin))
    trainer = render_app(scope(:trainer))

    assert "Team" in texts(admin, "#sidebar a")
    assert "Billing" in texts(admin, "#sidebar a")
    refute "Team" in texts(trainer, "#sidebar a")
    refute "Billing" in texts(trainer, "#sidebar a")
  end

  test "clients get Home and Settings only" do
    labels =
      scope(:client) |> render_app(:home) |> texts("#sidebar a") |> Enum.reject(&(&1 == ""))

    assert Enum.any?(labels, &String.contains?(&1, "Home"))
    refute Enum.any?(labels, &String.contains?(&1, "Clients"))
  end

  test "Nutrition carries a Pro tag on the Free plan" do
    html = render_app(scope(:trainer, tier: "free"))

    assert Enum.any?(texts(html, "#sidebar a"), &(&1 =~ "Nutrition" and &1 =~ "Pro"))
  end

  test "a read-only account shows the banner with the update action for org admins" do
    html = render_app(scope(:org_admin, subscription_status: "cancelled"))

    assert [banner] = texts(html, "[role=status]")
    assert banner =~ "Read-only"
    assert banner =~ "Update payment"
  end

  test "trainers on a read-only account are told who can fix it" do
    html =
      render_app(scope(:trainer, subscription_status: "cancelled", owner_name: "Wanjiru Njoroge"))

    assert [banner] = texts(html, "[role=status]")
    assert banner =~ "Wanjiru Njoroge can fix this"
  end

  test "healthy and client accounts show no banner" do
    assert [] = texts(render_app(scope(:org_admin)), "[role=status]")

    assert [] =
             texts(render_app(scope(:client, subscription_status: "cancelled")), "[role=status]")
  end

  test "the phone tab bar has a More button controlling the sheet" do
    html = render_app(scope(:org_admin))

    assert [_] = Enum.to_list(query(html, "button[aria-controls=more-sheet]"))
    assert Enum.any?(texts(html, "#more-sheet a"), &(&1 =~ "Team"))
  end

  test "visitors see the public header, not the shell" do
    html = render_app(%{user: nil}, nil)

    assert [] = Enum.to_list(query(html, "#sidebar"))
    assert Enum.any?(texts(html, "header a"), &(&1 =~ "Sign in"))
  end
end
