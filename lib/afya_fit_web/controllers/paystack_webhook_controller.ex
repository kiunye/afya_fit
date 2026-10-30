defmodule AfyaFitWeb.PaystackWebhookController do
  use AfyaFitWeb, :controller

  alias AfyaFit.Billing
  alias AfyaFit.Billing.Checkout

  @doc """
  Handles Paystack webhook events.
  """
  def webhook(conn, params) do
    if valid_signature?(conn) do
      process(conn, params)
    else
      conn |> put_status(:unauthorized) |> json(%{error: "invalid signature"})
    end
  end

  # Paystack signs the raw request body with the account's secret key
  # (HMAC-SHA512, hex) and sends it in `x-paystack-signature`.
  defp valid_signature?(conn) do
    with secret when is_binary(secret) <- Application.get_env(:paystack, :secret_key),
         raw when is_binary(raw) <- conn.assigns[:raw_body],
         [signature] <- get_req_header(conn, "x-paystack-signature") do
      expected = :crypto.mac(:hmac, :sha512, secret, raw) |> Base.encode16(case: :lower)
      Plug.Crypto.secure_compare(expected, String.downcase(signature))
    else
      _ -> false
    end
  end

  defp process(conn, params) do
    case params do
      %{"event" => "charge.success", "data" => data} ->
        handle_charge_success(conn, data)

      %{"event" => "subscription.create", "data" => data} ->
        handle_subscription_create(conn, data)

      %{"event" => "subscription.disable", "data" => data} ->
        handle_subscription_disable(conn, data)

      %{"event" => "invoice.create", "data" => data} ->
        handle_invoice_create(conn, data)

      %{"event" => "invoice.payment_failed", "data" => data} ->
        handle_payment_failed(conn, data)

      _ ->
        conn
        |> put_status(:ok)
        |> json(%{status: "ignored"})
    end
  end

  defp handle_charge_success(conn, data) do
    case Checkout.paystack_charge_success(data) do
      {:ok, _payment} ->
        conn |> put_status(:ok) |> json(%{status: "processed"})

      :unknown ->
        conn |> put_status(:ok) |> json(%{status: "ignored"})
    end
  end

  defp handle_subscription_create(conn, data) do
    subscription_code = data["subscription_code"]

    webhook_data = %{
      "status" => data["status"],
      "current_period_start" => data["current_period_start"],
      "current_period_end" => data["current_period_end"]
    }

    # Try organization subscription first
    case Billing.update_subscription_from_webhook(subscription_code, webhook_data) do
      {:ok, _subscription} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "processed"})

      {:error, :not_found} ->
        # Try client subscription
        case Billing.update_client_subscription_from_webhook(subscription_code, webhook_data) do
          {:ok, _subscription} ->
            conn
            |> put_status(:ok)
            |> json(%{status: "processed"})

          {:error, _reason} ->
            conn
            |> put_status(:ok)
            |> json(%{status: "error"})
        end

      {:error, _reason} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "error"})
    end
  end

  defp handle_subscription_disable(conn, data) do
    subscription_code = data["subscription_code"]

    webhook_data = %{
      "status" => "cancelled"
    }

    # Try organization subscription first
    case Billing.update_subscription_from_webhook(subscription_code, webhook_data) do
      {:ok, _subscription} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "processed"})

      {:error, :not_found} ->
        # Try client subscription
        case Billing.update_client_subscription_from_webhook(subscription_code, webhook_data) do
          {:ok, _subscription} ->
            conn
            |> put_status(:ok)
            |> json(%{status: "processed"})

          {:error, _reason} ->
            conn
            |> put_status(:ok)
            |> json(%{status: "error"})
        end

      {:error, _reason} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "error"})
    end
  end

  defp handle_invoice_create(conn, _data) do
    # Handle invoice creation
    conn
    |> put_status(:ok)
    |> json(%{status: "processed"})
  end

  defp handle_payment_failed(conn, data) do
    subscription_code = data["subscription_code"]

    webhook_data = %{
      "status" => "past_due"
    }

    # Try organization subscription first
    case Billing.update_subscription_from_webhook(subscription_code, webhook_data) do
      {:ok, _subscription} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "processed"})

      {:error, :not_found} ->
        # Try client subscription
        case Billing.update_client_subscription_from_webhook(subscription_code, webhook_data) do
          {:ok, _subscription} ->
            conn
            |> put_status(:ok)
            |> json(%{status: "processed"})

          {:error, _reason} ->
            conn
            |> put_status(:ok)
            |> json(%{status: "error"})
        end

      {:error, _reason} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "error"})
    end
  end
end
