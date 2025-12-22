defmodule AfyaFit.Payments.PaystackClient do
  @moduledoc """
  Wrapper around the official Paystack Elixir library.

  Provides a consistent interface for Paystack API interactions.
  Uses the official Paystack library from Hex: https://hex.pm/packages/paystack
  """

  @doc """
  Creates a Paystack customer.

  Returns `{:ok, Paystack.Response{}}` on success or `{:error, reason}` on failure.
  """
  def create_customer(email, first_name, last_name, phone \\ nil) do
    attrs = %{
      email: email,
      first_name: first_name,
      last_name: last_name
    }

    attrs = if phone, do: Map.put(attrs, :phone, phone), else: attrs

    Paystack.Customer.create(attrs)
  end

  @doc """
  Initializes a payment transaction.

  Returns `{:ok, Paystack.Response{}}` with authorization_url, access_code, and reference.
  """
  def initialize_transaction(email, amount, reference \\ nil, metadata \\ %{}) do
    # Amount should be in kobo/cents (smallest currency unit)
    amount_kobo = if is_integer(amount), do: amount, else: trunc(amount * 100)

    attrs = %{
      email: email,
      amount: Integer.to_string(amount_kobo),
      metadata: metadata
    }

    attrs = if reference, do: Map.put(attrs, :reference, reference), else: attrs

    Paystack.Transaction.initialize(attrs)
  end

  @doc """
  Verifies a payment transaction.

  Returns `{:ok, Paystack.Response{}}` with transaction details.
  """
  def verify_transaction(reference) do
    Paystack.Transaction.verify(reference)
  end

  @doc """
  Creates a subscription plan.

  Returns `{:ok, Paystack.Response{}}` on success.
  """
  def create_plan(name, amount, interval, currency \\ "NGN", description \\ nil) do
    # Amount should be in kobo/cents
    amount_kobo = if is_integer(amount), do: amount, else: trunc(amount * 100)

    attrs = %{
      name: name,
      amount: Integer.to_string(amount_kobo),
      interval: interval,
      currency: currency
    }

    attrs = if description, do: Map.put(attrs, :description, description), else: attrs

    Paystack.Plan.create(attrs)
  end

  @doc """
  Creates a subscription for a customer.

  Returns `{:ok, Paystack.Response{}}` on success.
  """
  def create_subscription(customer_code, plan_code, authorization_code \\ nil) do
    attrs = %{
      customer: customer_code,
      plan: plan_code
    }

    attrs =
      if authorization_code, do: Map.put(attrs, :authorization, authorization_code), else: attrs

    Paystack.Subscription.create(attrs)
  end

  @doc """
  Gets subscription details.

  Returns `{:ok, Paystack.Response{}}` with subscription data.
  """
  def get_subscription(subscription_code) do
    # Paystack library uses fetch/1 for getting subscriptions
    Paystack.Subscription.fetch(subscription_code)
  end

  @doc """
  Cancels/Disables a subscription.

  Returns `{:ok, Paystack.Response{}}` on success.
  """
  def cancel_subscription(subscription_code, _token \\ nil) do
    # Paystack library uses disable/1 (no attrs parameter)
    Paystack.Subscription.disable(subscription_code)
  end

  @doc """
  Generates a unique transaction reference.
  """
  def generate_reference do
    "AFYA_#{System.system_time(:second)}_#{:rand.uniform(10000)}"
  end
end
