defmodule AfyaFitWeb.BillingLiveTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures
  import Ecto.Query, only: [from: 2]
  import Phoenix.LiveViewTest

  alias AfyaFit.Billing
  alias AfyaFit.Billing.{Checkout, MpesaCallback, Payment}
  alias AfyaFit.Repo
  alias AfyaFit.Test.FakeGateways

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

  describe "dates" do
    test "are shown on the viewer's calendar", %{conn: conn, org: org, owner: owner} do
      # 22:30 UTC on 1 November is already 2 November in Nairobi.
      subscription(org, %{plan_type: "pro", current_period_end: ~U[2026-11-01 22:30:00Z]})
      {:ok, _} = AfyaFit.Accounts.update_timezone(owner, "Africa/Nairobi")

      {:ok, view, _} = conn |> log_in(AfyaFit.Repo.reload!(owner)) |> live(~p"/billing")

      assert has_element?(view, "#plan", "2 Nov")
      refute has_element?(view, "#plan", "1 Nov")
    end

    test "default to UTC", %{conn: conn, org: org, owner: owner} do
      subscription(org, %{plan_type: "pro", current_period_end: ~U[2026-11-01 22:30:00Z]})

      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/billing")

      assert has_element?(view, "#plan", "1 Nov")
    end
  end

  describe "paying" do
    defp open_methods(view, plan \\ "pro") do
      view |> element("#upgrade") |> render_click()
      view |> element("#choose-#{plan}") |> render_click()
    end

    test "upgrading shows the plans with their prices", %{conn: conn, owner: owner} do
      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/billing")

      view |> element("#upgrade") |> render_click()

      assert has_element?(view, "#plan-pro", "KES 1,500")
      assert has_element?(view, "#plan-enterprise", "KES 5,000")
    end

    test "choosing a plan offers card and M-Pesa", %{conn: conn, owner: owner} do
      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/billing")

      open_methods(view)

      assert has_element?(view, "#checkout-summary", "Pro plan")
      assert has_element?(view, "#pay-card")
      assert has_element?(view, "#mpesa-form")
    end

    test "cancelling closes the panel", %{conn: conn, owner: owner} do
      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/billing")
      open_methods(view)

      view |> element("#close-checkout") |> render_click()

      refute has_element?(view, "#checkout")
    end

    test "the card button sends the customer to Paystack", %{conn: conn, owner: owner} do
      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/billing")
      open_methods(view)

      assert {:error, {:redirect, %{to: "https://checkout.paystack.test/" <> reference}}} =
               view |> element("#pay-card") |> render_click()

      assert %Payment{provider: "paystack", status: "pending"} =
               Repo.get_by!(Payment, reference: reference)
    end

    test "coming back from Paystack settles a paid payment", %{conn: conn, org: org, owner: owner} do
      {:ok, payment, _} =
        Checkout.start_card(
          AfyaFit.Authorization.Scope.load(owner),
          "pro",
          "https://x.test/billing"
        )

      FakeGateways.set_verify(
        payment.reference,
        {:ok, %{status: "success", amount: payment.amount, currency: "KES"}}
      )

      # Paystack sends the customer back with the reference; the page settles
      # the payment and redirects to a clean URL, flash in hand.
      conn = log_in(conn, owner)

      {:ok, view, _} =
        conn |> live(~p"/billing?reference=#{payment.reference}") |> follow_redirect(conn)

      assert render(view) =~ "Paid. The Pro plan is active."
      assert has_element?(view, "#plan", "Pro plan")
      assert has_element?(view, "#invoices", "KES")
      assert Billing.get_subscription_by_organization(org.id).plan_type == "pro"
    end

    test "an unknown reference is said so", %{conn: conn, owner: owner} do
      conn = log_in(conn, owner)
      {:ok, view, _} = conn |> live(~p"/billing?reference=AFNOSUCH") |> follow_redirect(conn)

      assert render(view) =~ "We could not find that payment."
    end

    test "M-Pesa asks for a phone, waits, and updates when the payment goes through", ctx do
      %{conn: conn, org: org, owner: owner} = ctx
      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/billing")
      open_methods(view)

      view |> form("#mpesa-form", mpesa: %{phone: "0712 345 678"}) |> render_submit()

      assert has_element?(view, "#waiting", "254712345678")

      payment = Repo.get_by!(Payment, organization_id: org.id)

      FakeGateways.set_query(
        payment.provider_reference,
        {:ok, %{result_code: 0, description: "ok"}}
      )

      MpesaCallback.handle(payment.callback_token, %{
        "Body" => %{
          "stkCallback" => %{
            "CheckoutRequestID" => payment.provider_reference,
            "ResultCode" => 0,
            "CallbackMetadata" => %{
              "Item" => [
                %{"Name" => "Amount", "Value" => 1500},
                %{"Name" => "MpesaReceiptNumber", "Value" => "NLJ7RT61SV"}
              ]
            }
          }
        }
      })

      assert render(view) =~ "Paid. The Pro plan is active."
      refute has_element?(view, "#waiting")
      assert has_element?(view, "#plan", "Pro plan")
    end

    test "a cancelled M-Pesa prompt goes back to the choices", ctx do
      %{conn: conn, org: org, owner: owner} = ctx
      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/billing")
      open_methods(view)
      view |> form("#mpesa-form", mpesa: %{phone: "0712345678"}) |> render_submit()

      payment = Repo.get_by!(Payment, organization_id: org.id)

      MpesaCallback.handle(payment.callback_token, %{
        "Body" => %{
          "stkCallback" => %{
            "CheckoutRequestID" => payment.provider_reference,
            "ResultCode" => 1032,
            "ResultDesc" => "Request cancelled by user"
          }
        }
      })

      assert render(view) =~ "The payment did not go through. Nothing was charged."
      assert has_element?(view, "#mpesa-form")
    end

    test "a bad number is explained and nothing is sent", %{conn: conn, org: org, owner: owner} do
      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/billing")
      open_methods(view)

      view |> form("#mpesa-form", mpesa: %{phone: "12345"}) |> render_submit()

      assert render(view) =~ "Enter a Kenyan mobile number"
      assert Repo.all(from p in Payment, where: p.organization_id == ^org.id) == []
    end

    test "tampered plans are ignored", %{conn: conn, owner: owner} do
      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/billing")
      view |> element("#upgrade") |> render_click()

      render_hook(view, "choose_plan", %{"plan" => "free"})

      refute has_element?(view, "#checkout-summary")
    end

    test "fixing a failed payment goes straight to paying for the same plan", %{
      conn: conn,
      org: org,
      owner: owner
    } do
      subscription(org, %{
        status: "past_due",
        plan_type: "pro",
        current_period_end:
          DateTime.add(DateTime.utc_now(), -20, :day) |> DateTime.truncate(:second)
      })

      {:ok, view, _} = conn |> log_in(owner) |> live(~p"/billing")

      view |> element("#update-payment") |> render_click()

      assert has_element?(view, "#checkout-summary", "Pro plan")
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
