defmodule AfyaFit.Billing.CheckoutTest do
  use AfyaFit.DataCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Authorization.Scope

  alias AfyaFit.Billing.{
    Checkout,
    Invoice,
    MpesaCallback,
    Payment,
    Plans,
    Reconciler,
    Subscription
  }

  alias AfyaFit.Organizations.Organization
  alias AfyaFit.Repo
  alias AfyaFit.Shared.ActivityLog
  alias AfyaFit.Test.FakeGateways

  setup do
    org = organization(%{plan_type: "free"})
    owner = user(org, :org_admin)

    %{
      org: org,
      owner: owner,
      scope: Scope.load(owner),
      trainer_scope: org |> user(:trainer) |> Scope.load()
    }
  end

  defp callback_url(token), do: "https://afyafit.test/webhooks/mpesa/" <> token

  defp card!(scope, plan \\ "pro") do
    {:ok, payment, _url} = Checkout.start_card(scope, plan, "https://afyafit.test/billing")
    payment
  end

  defp mpesa!(scope, plan \\ "pro", phone \\ "0712345678") do
    {:ok, payment} = Checkout.start_mpesa(scope, plan, phone, &callback_url/1)
    payment
  end

  defp paid_card(payment, attrs \\ %{}) do
    FakeGateways.set_verify(
      payment.reference,
      {:ok, Map.merge(%{status: "success", amount: payment.amount, currency: "KES"}, attrs)}
    )
  end

  defp callback(payment, code, items \\ nil) do
    %{
      "Body" => %{
        "stkCallback" =>
          %{
            "MerchantRequestID" => "mr",
            "CheckoutRequestID" => payment.provider_reference,
            "ResultCode" => code,
            "ResultDesc" =>
              if(code == 0,
                do: "The service request is processed successfully.",
                else: "Request cancelled by user"
              )
          }
          |> Map.merge(
            if code == 0,
              do: %{
                "CallbackMetadata" => %{
                  "Item" =>
                    items ||
                      [
                        %{"Name" => "Amount", "Value" => Decimal.to_integer(payment.amount)},
                        %{"Name" => "MpesaReceiptNumber", "Value" => "NLJ7RT61SV"},
                        %{"Name" => "PhoneNumber", "Value" => 254_712_345_678}
                      ]
                }
              },
              else: %{}
          )
      }
    }
  end

  defp confirm_mpesa(payment, code \\ 0),
    do:
      FakeGateways.set_query(
        payment.provider_reference,
        {:ok, %{result_code: code, description: "x"}}
      )

  defp current_subscription(org), do: Repo.get_by(Subscription, organization_id: org.id)

  describe "start_card/3" do
    test "records a pending payment and sends the customer to Paystack", ctx do
      %{owner: owner, scope: scope} = ctx

      assert {:ok, %Payment{} = payment, url} =
               Checkout.start_card(scope, "pro", "https://afyafit.test/billing")

      assert payment.status == "pending"
      assert payment.provider == "paystack"
      assert payment.plan_type == "pro"
      assert Decimal.equal?(payment.amount, 1500)
      assert url == "https://checkout.paystack.test/" <> payment.reference

      assert %{email: email, amount: 1500, callback_url: "https://afyafit.test/billing"} =
               FakeGateways.sent(payment.reference)

      assert email == owner.email
    end

    test "only someone who manages billing may pay", %{trainer_scope: trainer} do
      assert {:error, :forbidden} = Checkout.start_card(trainer, "pro", "https://x.test/billing")
    end

    test "only paid plans are for sale", %{scope: scope} do
      for plan <- ["free", "gold", nil] do
        assert {:error, :unknown_plan} =
                 Checkout.start_card(scope, plan, "https://x.test/billing")
      end

      assert Repo.aggregate(Payment, :count) == 0
    end

    test "a Paystack outage leaves a failed payment and a plain error", %{org: org} do
      owner = user(org, :org_admin, %{email: "gateway-down@example.com"})

      assert {:error, :gateway} =
               Checkout.start_card(Scope.load(owner), "pro", "https://x.test/b")

      assert [%Payment{status: "failed"}] = Repo.all(Payment)
    end
  end

  describe "confirm_card/2" do
    test "a paid transaction puts the organization on the plan", ctx do
      %{org: org, scope: scope} = ctx
      payment = card!(scope)
      paid_card(payment)

      assert {:ok, %Payment{status: "succeeded", paid_at: %DateTime{}}} =
               Checkout.confirm_card(scope, payment.reference)

      sub = current_subscription(org)
      assert sub.plan_type == "pro"
      assert sub.status == "active"
      assert DateTime.diff(sub.current_period_end, sub.current_period_start, :day) == 30
      assert Repo.get!(Organization, org.id).plan_type == "pro"
      assert Scope.load(ctx.owner).tier == "pro"
    end

    test "writes a paid invoice and an activity entry", %{org: org, scope: scope} do
      payment = card!(scope)
      paid_card(payment)
      {:ok, _} = Checkout.confirm_card(scope, payment.reference)

      assert [%Invoice{status: "paid", currency: "KES"} = invoice] = Repo.all(Invoice)
      assert Decimal.equal?(invoice.amount, 1500)
      assert invoice.subscription_id == current_subscription(org).id

      assert %ActivityLog{} =
               Repo.get_by!(ActivityLog, organization_id: org.id, action: "billing.payment")
    end

    test "asking twice settles once", %{scope: scope} do
      payment = card!(scope)
      paid_card(payment)

      {:ok, _} = Checkout.confirm_card(scope, payment.reference)

      assert {:ok, %Payment{status: "succeeded"}} =
               Checkout.confirm_card(scope, payment.reference)

      assert Repo.aggregate(Invoice, :count) == 1
    end

    test "a payment that is still open stays pending", %{scope: scope} do
      payment = card!(scope)

      assert {:ok, %Payment{status: "pending"}} = Checkout.confirm_card(scope, payment.reference)
      assert nil == Repo.get_by(Subscription, organization_id: payment.organization_id)
    end

    test "a failed transaction fails the payment", %{scope: scope} do
      payment = card!(scope)

      FakeGateways.set_verify(
        payment.reference,
        {:ok, %{status: "failed", amount: payment.amount, currency: "KES"}}
      )

      assert {:ok, %Payment{status: "failed"}} = Checkout.confirm_card(scope, payment.reference)
    end

    test "too little money is refused, even though Paystack says success", %{
      org: org,
      scope: scope
    } do
      payment = card!(scope)
      paid_card(payment, %{amount: Decimal.new(10)})

      assert {:ok, %Payment{status: "failed", failure_reason: "amount or currency did not match"}} =
               Checkout.confirm_card(scope, payment.reference)

      assert nil == current_subscription(org)
    end

    test "the wrong currency is refused", %{scope: scope} do
      payment = card!(scope)
      paid_card(payment, %{currency: "USD"})

      assert {:ok, %Payment{status: "failed"}} = Checkout.confirm_card(scope, payment.reference)
    end

    test "paying more than the price is accepted", %{scope: scope} do
      payment = card!(scope)
      paid_card(payment, %{amount: Decimal.new(2000)})

      assert {:ok, %Payment{status: "succeeded"}} =
               Checkout.confirm_card(scope, payment.reference)
    end

    test "another organization's payment, or none, is not found", %{scope: scope} do
      other = Scope.load(user(organization(), :org_admin))
      payment = card!(other)
      paid_card(payment)

      assert {:error, :not_found} = Checkout.confirm_card(scope, payment.reference)
      assert {:error, :not_found} = Checkout.confirm_card(scope, "AFNOSUCHPAYMENT")
    end
  end

  describe "paystack_charge_success/1" do
    test "settles a payment of ours", %{org: org, scope: scope} do
      payment = card!(scope)

      event = %{
        "reference" => payment.reference,
        "status" => "success",
        "amount" => 150_000,
        "currency" => "KES"
      }

      assert {:ok, %Payment{status: "succeeded"}} = Checkout.paystack_charge_success(event)
      assert current_subscription(org).plan_type == "pro"
    end

    test "is idempotent: the same event twice pays once", %{scope: scope} do
      payment = card!(scope)

      event = %{
        "reference" => payment.reference,
        "status" => "success",
        "amount" => 150_000,
        "currency" => "KES"
      }

      {:ok, _} = Checkout.paystack_charge_success(event)
      {:ok, _} = Checkout.paystack_charge_success(event)

      assert Repo.aggregate(Invoice, :count) == 1
    end

    test "an underpaid event fails the payment", %{org: org, scope: scope} do
      payment = card!(scope)

      event = %{
        "reference" => payment.reference,
        "status" => "success",
        "amount" => 100,
        "currency" => "KES"
      }

      assert {:ok, %Payment{status: "failed"}} = Checkout.paystack_charge_success(event)
      assert nil == current_subscription(org)
    end

    test "a reference that is not ours is unknown" do
      assert :unknown =
               Checkout.paystack_charge_success(%{"reference" => "other", "status" => "success"})

      assert :unknown = Checkout.paystack_charge_success(%{})
    end
  end

  describe "start_mpesa/4" do
    test "sends the push to the normalised number with a secret callback", %{scope: scope} do
      payment = mpesa!(scope, "pro", "0712 345 678")

      assert payment.status == "pending"
      assert payment.phone == "254712345678"
      assert payment.provider_reference == "ws_CO_" <> payment.reference
      assert byte_size(payment.callback_token) >= 40

      assert %{amount: 1500, phone: "254712345678", callback_url: url} =
               FakeGateways.sent(payment.reference)

      assert url == callback_url(payment.callback_token)
    end

    test "every payment gets its own token", %{scope: scope} do
      assert mpesa!(scope).callback_token != mpesa!(scope).callback_token
    end

    test "a bad number never reaches Daraja", %{scope: scope} do
      assert {:error, :invalid_phone} =
               Checkout.start_mpesa(scope, "pro", "12345", &callback_url/1)

      assert Repo.aggregate(Payment, :count) == 0
    end

    test "a Daraja outage leaves a failed payment", %{scope: scope} do
      assert {:error, :gateway} =
               Checkout.start_mpesa(scope, "pro", "0799999999", &callback_url/1)

      assert [%Payment{status: "failed"}] = Repo.all(Payment)
    end

    test "only someone who manages billing may pay", %{trainer_scope: trainer} do
      assert {:error, :forbidden} =
               Checkout.start_mpesa(trainer, "pro", "0712345678", &callback_url/1)
    end
  end

  describe "mpesa_callback/2" do
    test "a confirmed success settles with the receipt", %{org: org, scope: scope} do
      payment = mpesa!(scope)
      confirm_mpesa(payment)

      assert :ok = MpesaCallback.handle(payment.callback_token, callback(payment, 0))

      assert %Payment{status: "succeeded", receipt: "NLJ7RT61SV"} = Repo.get!(Payment, payment.id)
      assert current_subscription(org).plan_type == "pro"
    end

    test "a success Daraja does not confirm waits for the reconciler", %{scope: scope} do
      payment = mpesa!(scope)

      MpesaCallback.handle(payment.callback_token, callback(payment, 0))

      assert Repo.get!(Payment, payment.id).status == "pending"
    end

    test "the wrong amount fails the payment", %{org: org, scope: scope} do
      payment = mpesa!(scope)
      confirm_mpesa(payment)

      items = [
        %{"Name" => "Amount", "Value" => 10},
        %{"Name" => "MpesaReceiptNumber", "Value" => "X"}
      ]

      MpesaCallback.handle(payment.callback_token, callback(payment, 0, items))

      assert Repo.get!(Payment, payment.id).status == "failed"
      assert nil == current_subscription(org)
    end

    test "a cancelled prompt fails the payment with Daraja's reason", %{scope: scope} do
      payment = mpesa!(scope)

      MpesaCallback.handle(payment.callback_token, callback(payment, 1032))

      assert %Payment{status: "failed", failure_reason: "Request cancelled by user"} =
               Repo.get!(Payment, payment.id)
    end

    test "a callback with the wrong token, or the wrong request, does nothing", %{scope: scope} do
      payment = mpesa!(scope)
      other = mpesa!(scope)
      confirm_mpesa(payment)

      MpesaCallback.handle("not-the-token", callback(payment, 0))
      MpesaCallback.handle(other.callback_token, callback(payment, 0))

      assert Repo.get!(Payment, payment.id).status == "pending"
      assert Repo.get!(Payment, other.id).status == "pending"
    end

    test "rubbish is accepted and ignored", %{scope: scope} do
      payment = mpesa!(scope)

      assert :ok = MpesaCallback.handle(payment.callback_token, %{"nonsense" => true})
      assert :ok = MpesaCallback.handle("x", %{})
      assert Repo.get!(Payment, payment.id).status == "pending"
    end

    test "the same callback twice pays once", %{scope: scope} do
      payment = mpesa!(scope)
      confirm_mpesa(payment)

      MpesaCallback.handle(payment.callback_token, callback(payment, 0))
      MpesaCallback.handle(payment.callback_token, callback(payment, 0))

      assert Repo.aggregate(Invoice, :count) == 1
    end

    test "a failure arriving after success changes nothing", %{scope: scope} do
      payment = mpesa!(scope)
      confirm_mpesa(payment)
      MpesaCallback.handle(payment.callback_token, callback(payment, 0))

      MpesaCallback.handle(payment.callback_token, callback(payment, 1032))

      assert Repo.get!(Payment, payment.id).status == "succeeded"
    end
  end

  describe "periods" do
    test "paying for the plan you are on adds a period to the end of the current one", ctx do
      %{org: org, scope: scope} = ctx
      first = card!(scope)
      paid_card(first)
      {:ok, _} = Checkout.confirm_card(scope, first.reference)
      first_end = current_subscription(org).current_period_end

      second = card!(scope)
      paid_card(second)
      {:ok, _} = Checkout.confirm_card(scope, second.reference)

      assert DateTime.diff(current_subscription(org).current_period_end, first_end, :day) == 30
      assert Repo.aggregate(Subscription, :count) == 1
    end

    test "another plan starts a new period", %{org: org, scope: scope} do
      pro = card!(scope, "pro")
      paid_card(pro)
      {:ok, _} = Checkout.confirm_card(scope, pro.reference)

      enterprise = card!(scope, "enterprise")
      paid_card(enterprise)
      {:ok, _} = Checkout.confirm_card(scope, enterprise.reference)

      sub = current_subscription(org)
      assert sub.plan_type == "enterprise"
      assert DateTime.diff(sub.current_period_end, DateTime.utc_now(), :day) in 29..30
    end

    test "paying clears a past-due account", %{org: org, owner: owner, scope: scope} do
      subscription(org, %{status: "past_due", plan_type: "pro"})

      payment = card!(scope)
      paid_card(payment)
      {:ok, _} = Checkout.confirm_card(scope, payment.reference)

      sub = current_subscription(org)
      assert sub.status == "active"
      assert sub.cancel_at_period_end == false
      assert Scope.load(owner) |> Scope.billing() |> Map.fetch!(:state) == :active
    end

    test "paying undoes a pending cancellation", %{org: org, scope: scope} do
      subscription(org, %{status: "cancelled", cancel_at_period_end: true, plan_type: "pro"})

      payment = card!(scope)
      paid_card(payment)
      {:ok, _} = Checkout.confirm_card(scope, payment.reference)

      assert %Subscription{status: "active", cancel_at_period_end: false} =
               current_subscription(org)
    end
  end

  describe "watching a payment" do
    test "settling tells subscribers", %{scope: scope} do
      payment = mpesa!(scope)
      Checkout.subscribe(payment)
      confirm_mpesa(payment)

      MpesaCallback.handle(payment.callback_token, callback(payment, 0))

      assert_receive {:payment_updated, %Payment{status: "succeeded"}}
    end

    test "failing tells subscribers", %{scope: scope} do
      payment = mpesa!(scope)
      Checkout.subscribe(payment)

      MpesaCallback.handle(payment.callback_token, callback(payment, 1032))

      assert_receive {:payment_updated, %Payment{status: "failed"}}
    end

    test "a payment is visible only to its own organization", %{scope: scope} do
      payment = mpesa!(scope)
      stranger = Scope.load(user(organization(), :org_admin))

      assert %Payment{} = Checkout.get_payment(scope, payment.id)
      assert nil == Checkout.get_payment(stranger, payment.id)
      assert nil == Checkout.get_payment(scope, "nope")
    end
  end

  describe "reconcile/2" do
    defp aged(payment, seconds) do
      at = DateTime.add(DateTime.utc_now(), -seconds, :second) |> DateTime.truncate(:second)
      Repo.update_all(from(p in Payment, where: p.id == ^payment.id), set: [inserted_at: at])
      Repo.get!(Payment, payment.id)
    end

    test "settles an M-Pesa payment whose callback never came", %{org: org, scope: scope} do
      payment = mpesa!(scope) |> aged(120)
      confirm_mpesa(payment)

      assert %Payment{status: "succeeded"} = Reconciler.reconcile(payment)
      assert current_subscription(org).plan_type == "pro"
    end

    test "fails one Daraja reports as failed", %{scope: scope} do
      payment = mpesa!(scope) |> aged(120)
      confirm_mpesa(payment, 1037)

      assert %Payment{status: "failed"} = Reconciler.reconcile(payment)
    end

    test "leaves an unanswered one pending, then expires it", %{scope: scope} do
      payment = mpesa!(scope)

      assert %Payment{status: "pending"} = Reconciler.reconcile(aged(payment, 120))
      assert %Payment{status: "expired"} = Reconciler.reconcile(aged(payment, 20 * 60))
    end

    test "settles a card payment Paystack reports as paid", %{scope: scope} do
      payment = card!(scope) |> aged(120)
      paid_card(payment)

      assert %Payment{status: "succeeded"} = Reconciler.reconcile(payment)
    end

    test "a card payment is given a day before it expires", %{scope: scope} do
      payment = card!(scope)

      assert %Payment{status: "pending"} = Reconciler.reconcile(aged(payment, 3600))
      assert %Payment{status: "expired"} = Reconciler.reconcile(aged(payment, 25 * 3600))
    end

    test "money that arrives after expiry still counts", %{org: org, scope: scope} do
      payment = card!(scope)
      expired = Reconciler.reconcile(aged(payment, 25 * 3600))
      assert expired.status == "expired"
      paid_card(payment)

      assert {:ok, %Payment{status: "succeeded"}} = Checkout.settle(expired)
      assert current_subscription(org).plan_type == "pro"
    end

    test "finished payments are left alone", %{scope: scope} do
      payment = card!(scope)
      paid_card(payment)
      {:ok, done} = Checkout.confirm_card(scope, payment.reference)

      assert ^done = Reconciler.reconcile(done)
    end

    test "stale_pending/1 lists only old pending payments", %{scope: scope} do
      old = mpesa!(scope) |> aged(300)
      _fresh = mpesa!(scope)
      finished = mpesa!(scope) |> aged(300)
      Checkout.fail(finished, "x")

      assert [%Payment{id: id}] = Reconciler.stale_pending()
      assert id == old.id
    end
  end

  test "prices come from one place", %{scope: scope} do
    assert Plans.price("pro") == 1500
    assert Plans.format(1500) == "KES 1,500"
    assert Decimal.equal?(card!(scope, "enterprise").amount, 5000)
  end
end
