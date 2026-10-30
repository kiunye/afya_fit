defmodule AfyaFit.Payments.DarajaTest do
  # The access token is cached node-wide, so these cannot run alongside each other.
  use ExUnit.Case, async: false

  alias AfyaFit.Payments.Daraja

  @config [
    base_url: "https://daraja.test",
    consumer_key: "key",
    consumer_secret: "secret",
    shortcode: "174379",
    passkey: "passkey",
    transaction_type: "CustomerPayBillOnline"
  ]

  setup do
    previous = Application.get_env(:afya_fit, Daraja)
    Application.put_env(:afya_fit, Daraja, Keyword.merge(previous, @config))
    Daraja.forget_token()

    on_exit(fn ->
      Application.put_env(:afya_fit, Daraja, previous)
      Daraja.forget_token()
    end)
  end

  defp stub(handler) do
    Req.Test.stub(Daraja, fn conn ->
      case conn.request_path do
        "/oauth/v1/generate" ->
          Req.Test.json(conn, %{"access_token" => "tok", "expires_in" => "3599"})

        _path ->
          handler.(conn)
      end
    end)
  end

  describe "normalize_phone/1" do
    test "accepts the ways Kenyans write a mobile number" do
      for input <- [
            "0712345678",
            "+254712345678",
            "254712345678",
            "712345678",
            "0712 345 678",
            "0712-345-678"
          ] do
        assert {:ok, "254712345678"} = Daraja.normalize_phone(input), input
      end

      assert {:ok, "254112345678"} = Daraja.normalize_phone("0112345678")
    end

    test "refuses everything else" do
      for input <- [
            "",
            "12345",
            "0812345678",
            "+255712345678",
            "07123456789",
            "phone",
            nil,
            712_345_678
          ] do
        assert :error = Daraja.normalize_phone(input), inspect(input)
      end
    end
  end

  describe "configured?/0" do
    test "needs every credential" do
      assert Daraja.configured?()

      current = Application.get_env(:afya_fit, Daraja)
      Application.put_env(:afya_fit, Daraja, Keyword.put(current, :passkey, nil))
      refute Daraja.configured?()
    end
  end

  describe "stk_push/1" do
    @request %{
      phone: "254712345678",
      amount: 1500,
      reference: "AFABCDEFGHIJKLMNOP",
      callback_url: "https://afyafit.test/webhooks/mpesa/secret"
    }

    test "sends the prompt and returns the ids to follow it by" do
      test = self()

      stub(fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test, {:push, conn, Jason.decode!(body)})

        Req.Test.json(conn, %{
          "ResponseCode" => "0",
          "CheckoutRequestID" => "ws_CO_1",
          "MerchantRequestID" => "mr_1"
        })
      end)

      assert {:ok, %{checkout_request_id: "ws_CO_1", merchant_request_id: "mr_1"}} =
               Daraja.stk_push(@request)

      assert_receive {:push, conn, body}
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer tok"]
      assert body["BusinessShortCode"] == "174379"
      assert body["Amount"] == 1500
      assert body["PartyA"] == "254712345678"
      assert body["PhoneNumber"] == "254712345678"
      assert body["CallBackURL"] == "https://afyafit.test/webhooks/mpesa/secret"
      assert body["AccountReference"] == "AFABCDEFGHIJ"

      assert body["Password"] ==
               Base.encode64("174379passkey" <> body["Timestamp"])
    end

    test "sends the OAuth credentials as basic auth, and reuses the token" do
      test = self()

      Req.Test.stub(Daraja, fn conn ->
        case conn.request_path do
          "/oauth/v1/generate" ->
            send(test, {:token_request, Plug.Conn.get_req_header(conn, "authorization")})
            Req.Test.json(conn, %{"access_token" => "tok"})

          _ ->
            Req.Test.json(conn, %{
              "ResponseCode" => "0",
              "CheckoutRequestID" => "c",
              "MerchantRequestID" => "m"
            })
        end
      end)

      assert {:ok, _} = Daraja.stk_push(@request)
      assert {:ok, _} = Daraja.stk_push(@request)

      assert_received {:token_request, ["Basic " <> credentials]}
      assert Base.decode64!(credentials) == "key:secret"
      refute_received {:token_request, _}
    end

    test "a refusal comes back as an error with Daraja's words" do
      stub(fn conn ->
        conn
        |> Plug.Conn.put_status(400)
        |> Req.Test.json(%{
          "errorCode" => "400.002.02",
          "errorMessage" => "Bad Request - Invalid PhoneNumber"
        })
      end)

      assert {:error, "Bad Request - Invalid PhoneNumber"} = Daraja.stk_push(@request)
    end

    test "no access token is an error" do
      Req.Test.stub(Daraja, fn conn -> Req.Test.json(conn, %{"oops" => true}) end)

      assert {:error, :no_access_token} = Daraja.stk_push(@request)
    end

    test "an unreachable Daraja is an error" do
      Req.Test.stub(Daraja, fn conn -> Req.Test.transport_error(conn, :econnrefused) end)

      assert {:error, _} = Daraja.stk_push(@request)
    end
  end

  describe "stk_query/1" do
    test "reports a finished payment" do
      stub(fn conn -> Req.Test.json(conn, %{"ResultCode" => "0", "ResultDesc" => "Success"}) end)

      assert {:ok, %{result_code: 0, description: "Success"}} = Daraja.stk_query("ws_CO_1")
    end

    test "reports a final failure with its code" do
      stub(fn conn ->
        Req.Test.json(conn, %{"ResultCode" => "1032", "ResultDesc" => "Request cancelled by user"})
      end)

      assert {:ok, %{result_code: 1032, description: "Request cancelled by user"}} =
               Daraja.stk_query("ws_CO_1")
    end

    test "an unanswered request has no result yet" do
      stub(fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{
          "errorCode" => "500.001.1001",
          "errorMessage" => "The transaction is being processed"
        })
      end)

      assert {:ok, %{result_code: nil}} = Daraja.stk_query("ws_CO_1")
    end
  end
end
