defmodule AfyaFitWeb.BillingLiveTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures
  import Phoenix.LiveViewTest

  alias AfyaFit.Billing

  setup do
    org = organization(%{plan_type: "free"})
    owner = user(org, :org_admin, %{first_name: "Wanjiru", last_name: "Njoroge"})
    %{org: org, owner: owner, trainer: user(org, :trainer), client: user(org, :client)}
  end

  test "trainers and clients get the permission sign", %{
    conn: conn,
    trainer: trainer,
    client: client
  } do
    for u <- [trainer, client] do
      {:ok, view, _} = conn |> log_in(u) |> live(~p"/billing")
      assert has_element?(view, "#denied", "Not for your role")
      refute has_element?(view, "#billing")
    end
  end

  describe "an organization on the Free plan" do
    test "offers the upgrade and has no invoices", %{conn: conn, owner: owner} do
      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/billing")

      assert has_element?(view, "#plan", "Free plan")
      assert has_element?(view, "#upgrade", "Upgrade to Pro")
      assert has_element?(view, "#invoices-empty", "No invoices yet")
    end
  end

  describe "an active paid plan" do
    setup %{org: org} do
      %{subscription: subscription(org, %{plan_type: "pro", status: "active"})}
    end

    test "shows the plan and status", %{conn: conn, owner: owner} do
      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/billing")

      assert has_element?(view, "#plan", "Pro plan")
      assert has_element?(view, "#status", "Active")
      refute has_element?(view, "#upgrade")
    end

    test "cancelling asks first, then keeps access until the period ends", ctx do
      %{conn: conn, owner: owner, org: org} = ctx
      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/billing")

      view |> element("#cancel-plan") |> render_click()
      assert has_element?(view, "#cancel-confirm", "You keep access until")

      view |> element("#keep-plan") |> render_click()
      refute has_element?(view, "#cancel-confirm")

      view |> element("#cancel-plan") |> render_click()
      view |> element("#confirm-cancel") |> render_click()

      assert Billing.get_subscription_by_organization(org.id).cancel_at_period_end
      assert has_element?(view, "#status", "Cancelling")
      refute has_element?(view, "[role=status]", "Read-only")
    end

    test "lists invoices as rows", %{conn: conn, owner: owner, subscription: subscription} do
      {:ok, _} =
        Billing.create_invoice_from_transaction(subscription.id, %{
          "reference" => "INV-0007",
          "amount" => 290_000,
          "currency" => "KES"
        })

      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/billing")
      assert has_element?(view, "#invoices [id^=invoices-]")
    end
  end

  describe "a lapsed account" do
    test "past due shows the status and the update action, and billing stays usable", ctx do
      %{conn: conn, owner: owner, org: org} = ctx

      subscription(org, %{
        status: "past_due",
        current_period_end:
          DateTime.add(DateTime.utc_now(), -20, :day) |> DateTime.truncate(:second)
      })

      {:ok, view, html} = conn |> log_in(owner) |> live(~p"/billing")

      assert has_element?(view, "#status", "Past due since")
      assert has_element?(view, "#update-payment", "Update payment")
      assert html =~ "Read-only"
    end
  end
end
