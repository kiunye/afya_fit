defmodule AfyaFitWeb.PaystackWebhookController do
  use AfyaFitWeb, :controller

  alias AfyaFit.Billing

  @doc """
  Handles Paystack webhook events.
  """
  def webhook(conn, params) do
    # Verify webhook signature (implement based on Paystack docs)
    # For now, we'll process the webhook

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

  defp handle_charge_success(conn, _data) do
    # Find subscription by customer code or transaction reference
    # Create invoice if needed
    # Update subscription status

    conn
    |> put_status(:ok)
    |> json(%{status: "processed"})
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
