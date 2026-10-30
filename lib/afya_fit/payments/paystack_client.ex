defmodule AfyaFit.Payments.PaystackClient do
  @moduledoc """
  Wrapper around the official Paystack Elixir library.

  Provides a consistent interface for Paystack API interactions.
  Uses the official Paystack library from Hex: https://hex.pm/packages/paystack
  """

  @doc "Whether the secret key is set, so checkout can be offered."
  def enabled?, do: is_binary(Application.get_env(:paystack, :secret_key))

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

  Amount should be in Kenyan Shillings (KES). Paystack requires amounts in cents
  (smallest currency unit), so we multiply by 100 to convert shillings to cents.
  """
  def initialize_transaction(email, amount, reference \\ nil, metadata \\ %{}) do
    # Paystack requires amounts in cents (100 cents = 1 KES shilling)
    amount_cents = if is_integer(amount), do: amount * 100, else: trunc(amount * 100)

    attrs = %{
      email: email,
      amount: Integer.to_string(amount_cents),
      currency: "KES",
      metadata: metadata
    }

    attrs = if reference, do: Map.put(attrs, :reference, reference), else: attrs

    Paystack.Transaction.initialize(attrs)
  end

  @doc """
  Starts a hosted checkout (card, or M-Pesa where Paystack offers it) and
  returns the page to send the customer to. `amount` is whole shillings. When
  the customer is done Paystack sends them to `callback_url`.
  """
  @spec checkout(String.t(), integer(), String.t(), map(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def checkout(email, amount, reference, metadata, callback_url) do
    attrs = %{
      email: email,
      amount: Integer.to_string(amount * 100),
      currency: "KES",
      reference: reference,
      metadata: metadata,
      callback_url: callback_url
    }

    case Paystack.Transaction.initialize(attrs) do
      {:ok, %Paystack.Response{success: true, data: %{"authorization_url" => url}}} ->
        {:ok, url}

      {:ok, %Paystack.Response{message: message}} ->
        {:error, message}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  What Paystack says about a transaction: its `status` (`"success"`,
  `"failed"`, `"abandoned"`...), the `amount` in shillings and the currency.
  """
  @spec verify(String.t()) ::
          {:ok, %{status: String.t(), amount: Decimal.t(), currency: String.t()}}
          | {:error, term()}
  def verify(reference) do
    case Paystack.Transaction.verify(reference) do
      {:ok, %Paystack.Response{success: true, data: data}} ->
        {:ok,
         %{
           status: data["status"],
           amount: data["amount"] |> Decimal.new() |> Decimal.div(100),
           currency: data["currency"]
         }}

      {:ok, %Paystack.Response{message: message}} ->
        {:error, message}

      {:error, reason} ->
        {:error, reason}
    end
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

  Amount should be in Kenyan Shillings (KES). Paystack requires amounts in cents
  (smallest currency unit), so we multiply by 100 to convert shillings to cents.
  """
  def create_plan(name, amount, interval, currency \\ "KES", description \\ nil) do
    # Paystack requires amounts in cents (100 cents = 1 KES shilling)
    amount_cents = if is_integer(amount), do: amount * 100, else: trunc(amount * 100)

    attrs = %{
      name: name,
      amount: Integer.to_string(amount_cents),
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
