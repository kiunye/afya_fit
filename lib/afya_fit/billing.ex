defmodule AfyaFit.Billing do
  @moduledoc """
  The Billing context.
  """
  import Ecto.Query, warn: false
  alias AfyaFit.Billing.{ClientSubscription, Invoice, Subscription}
  alias AfyaFit.Payments.PaystackClient
  alias AfyaFit.Repo

  @doc """
  Gets subscription for an organization.
  """
  def get_subscription_by_organization(organization_id) do
    Repo.get_by(Subscription, organization_id: organization_id)
    |> Repo.preload(:invoices)
  end

  @doc """
  Creates a subscription with Paystack integration.
  """
  def create_subscription(organization, plan_type, customer_email, customer_name) do
    # Create Paystack customer
    case PaystackClient.create_customer(customer_email, customer_name, "") do
      {:ok, %Paystack.Response{success: true, data: customer_data}} ->
        customer_code = customer_data["customer_code"]

        # Create subscription in database
        now = DateTime.utc_now()
        period_end = DateTime.add(now, 30, :day)

        attrs = %{
          organization_id: organization.id,
          plan_type: plan_type,
          status: "active",
          paystack_customer_code: customer_code,
          current_period_start: now,
          current_period_end: period_end
        }

        case Repo.insert(Subscription.changeset(%Subscription{}, attrs)) do
          {:ok, subscription} ->
            {:ok, subscription}

          {:error, changeset} ->
            {:error, changeset}
        end

      {:ok, %Paystack.Response{success: false, message: message}} ->
        {:error, "Paystack error: #{message}"}

      {:error, reason} ->
        {:error, "Failed to create Paystack customer: #{inspect(reason)}"}
    end
  end

  @doc """
  Updates subscription status from Paystack webhook.
  """
  def update_subscription_from_webhook(subscription_code, webhook_data) do
    case Repo.get_by(Subscription, paystack_subscription_code: subscription_code) do
      nil ->
        {:error, :not_found}

      subscription ->
        status = Map.get(webhook_data, "status", subscription.status)
        current_period_start = parse_datetime(webhook_data["current_period_start"])
        current_period_end = parse_datetime(webhook_data["current_period_end"])

        attrs = %{
          status: normalize_status(status),
          paystack_subscription_code: subscription_code,
          current_period_start: current_period_start || subscription.current_period_start,
          current_period_end: current_period_end || subscription.current_period_end
        }

        subscription
        |> Subscription.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Updates a subscription.
  """
  def update_subscription(subscription, attrs) do
    subscription
    |> Subscription.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Cancels a subscription.
  """
  def cancel_subscription(subscription) do
    if subscription.paystack_subscription_code do
      case PaystackClient.cancel_subscription(subscription.paystack_subscription_code) do
        {:ok, %Paystack.Response{success: true}} ->
          attrs = %{
            status: "cancelled",
            cancel_at_period_end: true,
            cancelled_at: DateTime.utc_now()
          }

          subscription
          |> Subscription.changeset(attrs)
          |> Repo.update()

        _ ->
          # Still mark as cancelled locally even if Paystack call fails
          attrs = %{
            status: "cancelled",
            cancel_at_period_end: true,
            cancelled_at: DateTime.utc_now()
          }

          subscription
          |> Subscription.changeset(attrs)
          |> Repo.update()
      end
    else
      attrs = %{
        status: "cancelled",
        cancel_at_period_end: true,
        cancelled_at: DateTime.utc_now()
      }

      subscription
      |> Subscription.changeset(attrs)
      |> Repo.update()
    end
  end

  @doc """
  Creates an invoice from Paystack transaction.

  Paystack returns amounts in cents (smallest currency unit for KES).
  We divide by 100 to convert cents back to shillings for storage.
  """
  def create_invoice_from_transaction(subscription_id, transaction_data) do
    invoice_number = generate_invoice_number()
    # Paystack amounts are in cents (100 cents = 1 KES shilling)
    amount_cents = transaction_data["amount"]

    amount =
      case amount_cents do
        amount when is_integer(amount) -> Decimal.new(amount) |> Decimal.div(100)
        amount when is_float(amount) -> Decimal.from_float(amount / 100)
        amount when is_binary(amount) -> Decimal.new(amount) |> Decimal.div(100)
        _ -> Decimal.new(0)
      end

    currency = transaction_data["currency"] || "KES"

    attrs = %{
      subscription_id: subscription_id,
      invoice_number: invoice_number,
      amount: amount,
      currency: currency,
      status: "paid",
      paystack_invoice_code: transaction_data["reference"],
      due_date: Date.utc_today(),
      paid_at: parse_datetime(transaction_data["paid_at"])
    }

    %Invoice{}
    |> Invoice.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists invoices for a subscription.
  """
  def list_invoices(subscription_id) do
    Invoice
    |> where([i], i.subscription_id == ^subscription_id)
    |> order_by([i], desc: i.inserted_at)
    |> Repo.all()
  end

  defp normalize_status("active"), do: "active"
  defp normalize_status("cancelled"), do: "cancelled"
  defp normalize_status("expired"), do: "expired"
  defp normalize_status("past_due"), do: "past_due"
  defp normalize_status(_), do: "active"

  defp parse_datetime(nil), do: nil

  defp parse_datetime(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp)
  end

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp generate_invoice_number do
    "INV-#{Date.utc_today() |> Date.to_string() |> String.replace("-", "")}-#{:rand.uniform(10000)}"
  end

  # Client Subscription Functions

  @doc """
  Gets client subscription for a user.
  """
  def get_client_subscription_by_client(client_id) do
    Repo.get_by(ClientSubscription, client_id: client_id)
  end

  @doc """
  Creates a client subscription with Paystack integration.
  """
  def create_client_subscription(client, organization, plan_type, customer_email, customer_name) do
    # Create Paystack customer
    case PaystackClient.create_customer(customer_email, customer_name, "") do
      {:ok, %Paystack.Response{success: true, data: customer_data}} ->
        customer_code = customer_data["customer_code"]

        # Calculate period end based on plan type
        now = DateTime.utc_now()

        period_end =
          case plan_type do
            "monthly" -> DateTime.add(now, 30, :day)
            "quarterly" -> DateTime.add(now, 90, :day)
            "yearly" -> DateTime.add(now, 365, :day)
            _ -> DateTime.add(now, 30, :day)
          end

        attrs = %{
          client_id: client.id,
          organization_id: organization.id,
          plan_type: plan_type,
          status: "active",
          paystack_customer_code: customer_code,
          current_period_start: now,
          current_period_end: period_end,
          reminder_preferences: %{
            "enabled" => true,
            "days_before_expiry" => [7, 3, 1]
          }
        }

        case Repo.insert(ClientSubscription.changeset(%ClientSubscription{}, attrs)) do
          {:ok, subscription} ->
            {:ok, subscription}

          {:error, changeset} ->
            {:error, changeset}
        end

      {:ok, %Paystack.Response{success: false, message: message}} ->
        {:error, "Paystack error: #{message}"}

      {:error, reason} ->
        {:error, "Failed to create Paystack customer: #{inspect(reason)}"}
    end
  end

  @doc """
  Updates client subscription from Paystack webhook.
  """
  def update_client_subscription_from_webhook(subscription_code, webhook_data) do
    case Repo.get_by(ClientSubscription, paystack_subscription_code: subscription_code) do
      nil ->
        {:error, :not_found}

      subscription ->
        status = Map.get(webhook_data, "status", subscription.status)
        current_period_start = parse_datetime(webhook_data["current_period_start"])
        current_period_end = parse_datetime(webhook_data["current_period_end"])

        attrs = %{
          status: normalize_status(status),
          paystack_subscription_code: subscription_code,
          current_period_start: current_period_start || subscription.current_period_start,
          current_period_end: current_period_end || subscription.current_period_end
        }

        subscription
        |> ClientSubscription.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Updates client subscription reminder preferences.
  """
  def update_client_subscription_reminders(subscription, reminder_prefs) do
    attrs = %{reminder_preferences: reminder_prefs}

    subscription
    |> ClientSubscription.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Cancels a client subscription.
  """
  def cancel_client_subscription(subscription) do
    if subscription.paystack_subscription_code do
      case PaystackClient.cancel_subscription(subscription.paystack_subscription_code) do
        {:ok, %Paystack.Response{success: true}} ->
          attrs = %{
            status: "cancelled",
            cancel_at_period_end: true,
            cancelled_at: DateTime.utc_now()
          }

          subscription
          |> ClientSubscription.changeset(attrs)
          |> Repo.update()

        _ ->
          # Still mark as cancelled locally even if Paystack call fails
          attrs = %{
            status: "cancelled",
            cancel_at_period_end: true,
            cancelled_at: DateTime.utc_now()
          }

          subscription
          |> ClientSubscription.changeset(attrs)
          |> Repo.update()
      end
    else
      attrs = %{
        status: "cancelled",
        cancel_at_period_end: true,
        cancelled_at: DateTime.utc_now()
      }

      subscription
      |> ClientSubscription.changeset(attrs)
      |> Repo.update()
    end
  end

  @doc """
  Lists client subscriptions expiring soon (for reminder emails).
  """
  def list_expiring_client_subscriptions(days_ahead) do
    cutoff_date = DateTime.add(DateTime.utc_now(), days_ahead, :day)

    ClientSubscription
    |> where([cs], cs.status == "active")
    |> where([cs], cs.current_period_end <= ^cutoff_date)
    |> where([cs], cs.current_period_end >= ^DateTime.utc_now())
    |> preload([:client, :organization])
    |> Repo.all()
  end
end
