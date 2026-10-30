defmodule AfyaFitWeb.PaymentWebhooksTest do
  # Sets the Paystack secret for the whole node.
  use AfyaFitWeb.ConnCase, async: false

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Billing.{Checkout, Payment, Subscription}
  alias AfyaFit.Repo
  alias AfyaFit.Test.FakeGateways

  @secret "sk_test_webhook_secret"

  setup do
    previous = Application.get_env(:paystack, :secret_key)
    Application.put_env(:paystack, :secret_key, @secret)
    on_exit(fn -> Application.put_env(:paystack, :secret_key, previous) end)

    org = organization(%{plan_type: "free"})
    scope = org |> user(:org_admin) |> Scope.load()
    %{org: org, scope: scope}
  end

  defp sign(body), do: :crypto.mac(:hmac, :sha512, @secret, body) |> Base.encode16(case: :lower)

  defp post_json(conn, path, body, headers \\ []) do
    conn = put_req_header(conn, "content-type", "application/json")
    conn = Enum.reduce(headers, conn, fn {key, value}, acc -> put_req_header(acc, key, value) end)
    post(conn, path, body)
  end

  defp charge_event(payment, overrides \\ %{}) do
    Jason.encode!(%{
      "event" => "charge.success",
      "data" =>
        Map.merge(
          %{
            "reference" => payment.reference,
            "status" => "success",
            "amount" => 150_000,
            "currency" => "KES"
          },
          overrides
        )
    })
  end

  defp card!(scope) do
    {:ok, payment, _} = Checkout.start_card(scope, "pro", "https://afyafit.test/billing")
    payment
  end

  describe "POST /webhooks/paystack" do
    test "a signed charge settles the payment", %{conn: conn, org: org, scope: scope} do
      payment = card!(scope)
      body = charge_event(payment)

      conn = post_json(conn, ~p"/webhooks/paystack", body, [{"x-paystack-signature", sign(body)}])

      assert %{"status" => "processed"} = json_response(conn, 200)
      assert %Payment{status: "succeeded"} = Repo.get!(Payment, payment.id)
      assert %Subscription{plan_type: "pro"} = Repo.get_by!(Subscription, organization_id: org.id)
    end

    test "a bad signature is refused and changes nothing", %{conn: conn, scope: scope} do
      payment = card!(scope)
      body = charge_event(payment)

      conn =
        post_json(conn, ~p"/webhooks/paystack", body, [
          {"x-paystack-signature", String.duplicate("0", 128)}
        ])

      assert json_response(conn, 401)
      assert Repo.get!(Payment, payment.id).status == "pending"
    end

    test "a missing signature is refused", %{conn: conn, scope: scope} do
      payment = card!(scope)

      conn = post_json(conn, ~p"/webhooks/paystack", charge_event(payment))

      assert json_response(conn, 401)
      assert Repo.get!(Payment, payment.id).status == "pending"
    end

    test "a signature for a different body is refused", %{conn: conn, scope: scope} do
      payment = card!(scope)
      signed = charge_event(payment, %{"amount" => 100})
      sent = charge_event(payment)

      conn =
        post_json(conn, ~p"/webhooks/paystack", sent, [{"x-paystack-signature", sign(signed)}])

      assert json_response(conn, 401)
      assert Repo.get!(Payment, payment.id).status == "pending"
    end

    test "no secret configured means nothing is believed", %{conn: conn, scope: scope} do
      Application.put_env(:paystack, :secret_key, nil)
      payment = card!(scope)
      body = charge_event(payment)

      conn = post_json(conn, ~p"/webhooks/paystack", body, [{"x-paystack-signature", sign(body)}])

      assert json_response(conn, 401)
    end

    test "the same event twice pays once", %{conn: conn, scope: scope} do
      payment = card!(scope)
      body = charge_event(payment)
      headers = [{"x-paystack-signature", sign(body)}]

      post_json(conn, ~p"/webhooks/paystack", body, headers)
      conn = post_json(build_conn(), ~p"/webhooks/paystack", body, headers)

      assert json_response(conn, 200)
      assert Repo.aggregate(AfyaFit.Billing.Invoice, :count) == 1
    end

    test "an underpaid charge fails the payment", %{conn: conn, org: org, scope: scope} do
      payment = card!(scope)
      body = charge_event(payment, %{"amount" => 100})

      post_json(conn, ~p"/webhooks/paystack", body, [{"x-paystack-signature", sign(body)}])

      assert Repo.get!(Payment, payment.id).status == "failed"
      assert nil == Repo.get_by(Subscription, organization_id: org.id)
    end

    test "a charge that is not ours is ignored", %{conn: conn} do
      body = Jason.encode!(%{"event" => "charge.success", "data" => %{"reference" => "other"}})

      conn = post_json(conn, ~p"/webhooks/paystack", body, [{"x-paystack-signature", sign(body)}])

      assert %{"status" => "ignored"} = json_response(conn, 200)
    end

    test "other events are acknowledged", %{conn: conn} do
      body = Jason.encode!(%{"event" => "transfer.success", "data" => %{}})

      conn = post_json(conn, ~p"/webhooks/paystack", body, [{"x-paystack-signature", sign(body)}])

      assert %{"status" => "ignored"} = json_response(conn, 200)
    end
  end

  describe "POST /webhooks/mpesa/:token" do
    defp mpesa!(scope) do
      {:ok, payment} =
        Checkout.start_mpesa(
          scope,
          "pro",
          "0712345678",
          &"https://afyafit.test/webhooks/mpesa/#{&1}"
        )

      payment
    end

    defp stk_body(payment, code) do
      Jason.encode!(%{
        "Body" => %{
          "stkCallback" => %{
            "MerchantRequestID" => "mr",
            "CheckoutRequestID" => payment.provider_reference,
            "ResultCode" => code,
            "ResultDesc" => "done",
            "CallbackMetadata" => %{
              "Item" => [
                %{"Name" => "Amount", "Value" => 1500},
                %{"Name" => "MpesaReceiptNumber", "Value" => "NLJ7RT61SV"}
              ]
            }
          }
        }
      })
    end

    test "a callback Daraja confirms settles the payment", %{conn: conn, org: org, scope: scope} do
      payment = mpesa!(scope)

      FakeGateways.set_query(
        payment.provider_reference,
        {:ok, %{result_code: 0, description: "ok"}}
      )

      conn = post_json(conn, ~p"/webhooks/mpesa/#{payment.callback_token}", stk_body(payment, 0))

      assert %{"ResultCode" => 0, "ResultDesc" => "Accepted"} = json_response(conn, 200)
      assert %Payment{status: "succeeded", receipt: "NLJ7RT61SV"} = Repo.get!(Payment, payment.id)
      assert %Subscription{plan_type: "pro"} = Repo.get_by!(Subscription, organization_id: org.id)
    end

    test "a callback Daraja does not confirm is accepted but not believed", %{
      conn: conn,
      scope: scope
    } do
      payment = mpesa!(scope)

      conn = post_json(conn, ~p"/webhooks/mpesa/#{payment.callback_token}", stk_body(payment, 0))

      assert %{"ResultCode" => 0} = json_response(conn, 200)
      assert Repo.get!(Payment, payment.id).status == "pending"
    end

    test "a guessed token is accepted and does nothing", %{conn: conn, scope: scope} do
      payment = mpesa!(scope)

      FakeGateways.set_query(
        payment.provider_reference,
        {:ok, %{result_code: 0, description: "ok"}}
      )

      conn = post_json(conn, ~p"/webhooks/mpesa/guess", stk_body(payment, 0))

      assert %{"ResultCode" => 0} = json_response(conn, 200)
      assert Repo.get!(Payment, payment.id).status == "pending"
    end

    test "a cancelled prompt fails the payment", %{conn: conn, scope: scope} do
      payment = mpesa!(scope)

      post_json(conn, ~p"/webhooks/mpesa/#{payment.callback_token}", stk_body(payment, 1032))

      assert Repo.get!(Payment, payment.id).status == "failed"
    end

    test "garbage is accepted", %{conn: conn} do
      conn = post_json(conn, ~p"/webhooks/mpesa/anything", Jason.encode!(%{"hello" => "world"}))

      assert %{"ResultCode" => 0} = json_response(conn, 200)
    end
  end
end
