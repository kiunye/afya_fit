defmodule AfyaFit.PaymentsTest do
  # Swaps the configured gateways and the Paystack key for the whole node.
  use ExUnit.Case, async: false

  alias AfyaFit.Payments
  alias AfyaFit.Payments.{Daraja, PaystackClient}

  setup do
    gateways =
      Application.get_all_env(:afya_fit) |> Keyword.take([:paystack_gateway, :mpesa_gateway])

    daraja = Application.get_env(:afya_fit, Daraja)
    key = Application.get_env(:paystack, :secret_key)

    Application.put_env(:afya_fit, :paystack_gateway, PaystackClient)
    Application.put_env(:afya_fit, :mpesa_gateway, Daraja)

    on_exit(fn ->
      Enum.each(gateways, fn {name, module} -> Application.put_env(:afya_fit, name, module) end)
      Application.put_env(:afya_fit, Daraja, daraja)
      Application.put_env(:paystack, :secret_key, key)
    end)
  end

  test "the test gateways are always on" do
    Application.put_env(:afya_fit, :paystack_gateway, AfyaFit.Test.FakePaystack)
    Application.put_env(:afya_fit, :mpesa_gateway, AfyaFit.Test.FakeMpesa)

    assert Payments.paystack_enabled?()
    assert Payments.mpesa_enabled?()
  end

  test "card payments need the Paystack secret key" do
    Application.put_env(:paystack, :secret_key, nil)
    refute Payments.paystack_enabled?()

    Application.put_env(:paystack, :secret_key, "sk_test_x")
    assert Payments.paystack_enabled?()
  end

  test "M-Pesa needs every Daraja credential" do
    complete = [consumer_key: "k", consumer_secret: "s", shortcode: "174379", passkey: "p"]
    current = Application.get_env(:afya_fit, Daraja)

    Application.put_env(:afya_fit, Daraja, Keyword.merge(current, complete))
    assert Payments.mpesa_enabled?()

    Application.put_env(
      :afya_fit,
      Daraja,
      Keyword.merge(current, Keyword.put(complete, :passkey, nil))
    )

    refute Payments.mpesa_enabled?()
  end
end
