defmodule AfyaFit.Dev.PaymentSimulatorTest do
  # Swaps the configured gateways for the whole node.
  use AfyaFit.DataCase, async: false

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Billing.{Checkout, Payment, Subscription}
  alias AfyaFit.Dev.{PaymentSimulator, SimulatedMpesa, SimulatedPaystack}
  alias AfyaFit.Repo

  setup do
    previous = Application.get_all_env(:afya_fit)

    Application.put_env(:afya_fit, :paystack_gateway, SimulatedPaystack)
    Application.put_env(:afya_fit, :mpesa_gateway, SimulatedMpesa)
    Application.put_env(:afya_fit, :sim_delay_ms, 30)

    # Let any simulated phone finish answering before the test's database goes away.
    on_exit(fn ->
      settle_time()
      Application.put_env(:afya_fit, :paystack_gateway, previous[:paystack_gateway])
      Application.put_env(:afya_fit, :mpesa_gateway, previous[:mpesa_gateway])
      Application.delete_env(:afya_fit, :sim_delay_ms)
    end)

    org = organization(%{plan_type: "free"})
    %{org: org, scope: org |> user(:org_admin) |> Scope.load()}
  end

  defp callback_url(token), do: "https://afyafit.test/webhooks/mpesa/" <> token

  defp settle_time, do: Process.sleep(PaymentSimulator.delay_ms() * 5 + 50)

  describe "M-Pesa" do
    test "a number answers after a delay, through the real callback", %{org: org, scope: scope} do
      {:ok, payment} = Checkout.start_mpesa(scope, "pro", "0712345678", &callback_url/1)
      assert payment.status == "pending"
      assert payment.provider_reference == "ws_SIM_" <> payment.reference

      # Nobody has answered yet.
      assert {:ok, %{result_code: nil}} = SimulatedMpesa.stk_query(payment.provider_reference)

      settle_time()

      assert %Payment{status: "succeeded", receipt: "SIM" <> _} = Repo.get!(Payment, payment.id)
      assert %Subscription{plan_type: "pro"} = Repo.get_by!(Subscription, organization_id: org.id)
      assert {:ok, %{result_code: 0}} = SimulatedMpesa.stk_query(payment.provider_reference)
    end

    test "a number ending in 0 is cancelled", %{scope: scope} do
      {:ok, payment} = Checkout.start_mpesa(scope, "pro", "0712345670", &callback_url/1)

      settle_time()

      assert %Payment{status: "failed", failure_reason: "Request cancelled by user"} =
               Repo.get!(Payment, payment.id)
    end

    test "the reconciler can settle it if the callback was missed", %{scope: scope} do
      {:ok, payment} = Checkout.start_mpesa(scope, "pro", "0712345678", &callback_url/1)
      PaymentSimulator.put({:stk, payment.provider_reference}, :paid)

      assert %Payment{status: "succeeded"} = AfyaFit.Billing.Reconciler.reconcile(payment)
    end
  end

  describe "card" do
    test "checkout points at a page on the app's own host", %{scope: scope} do
      {:ok, payment, url} = Checkout.start_card(scope, "pro", "http://localhost:4000/billing")

      assert url == "http://localhost:4000/dev/pay/#{payment.reference}"
    end

    test "is open until someone decides", %{scope: scope} do
      {:ok, payment, _url} = Checkout.start_card(scope, "pro", "http://localhost:4000/billing")

      assert {:ok, %Payment{status: "pending"}} = Checkout.confirm_card(scope, payment.reference)
    end

    test "Pay settles it, Fail fails it", %{org: org, scope: scope} do
      {:ok, paid, _} = Checkout.start_card(scope, "pro", "http://localhost:4000/billing")
      {:ok, failed, _} = Checkout.start_card(scope, "enterprise", "http://localhost:4000/billing")

      PaymentSimulator.put({:card, paid.reference}, :success)
      PaymentSimulator.put({:card, failed.reference}, :failed)

      assert {:ok, %Payment{status: "succeeded"}} = Checkout.confirm_card(scope, paid.reference)
      assert {:ok, %Payment{status: "failed"}} = Checkout.confirm_card(scope, failed.reference)
      assert %Subscription{plan_type: "pro"} = Repo.get_by!(Subscription, organization_id: org.id)
    end
  end

  test "both simulators say they are on" do
    assert SimulatedPaystack.enabled?()
    assert SimulatedMpesa.enabled?()
    assert AfyaFit.Payments.paystack_enabled?()
    assert AfyaFit.Payments.mpesa_enabled?()
  end
end
