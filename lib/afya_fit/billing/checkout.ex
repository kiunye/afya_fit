defmodule AfyaFit.Billing.Checkout do
  @moduledoc """
  Paying for a plan, by card (Paystack's hosted checkout) or M-Pesa (an STK push
  through Daraja).

  Every attempt is a `Payment` row. A payment *settles* when the provider says
  it is paid and the amount matches: the organization is put on the plan for
  one 30-day period (extended if it is already on that plan), an invoice is
  written, and anyone watching the payment is told. Settling is idempotent, so
  a webhook, the return page and the reconciler can all report the same payment
  without paying twice.

  Nothing here trusts a browser or a webhook body on its own: Paystack events
  are signed (checked in the controller) and M-Pesa callbacks are confirmed with
  Daraja before they count (`AfyaFit.Billing.MpesaCallback`). Payments whose
  webhook never came are caught by `AfyaFit.Billing.Reconciler`.
  """

  import Ecto.Query

  alias AfyaFit.{Authorization, Billing, Payments, Repo, Shared}
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Billing.{Invoice, Payment, Plans}
  alias AfyaFit.Organizations.Organization

  require Logger

  ## Starting

  @doc """
  Starts a card checkout. Returns the payment and the Paystack page to send the
  customer to; `return_url` is where Paystack sends them afterwards.
  """
  @spec start_card(Scope.t(), String.t(), String.t()) ::
          {:ok, Payment.t(), String.t()} | {:error, term()}
  def start_card(%Scope{} = scope, plan, return_url) do
    with {:ok, payment} <- create_payment(scope, "paystack", plan, %{}) do
      metadata = %{
        payment_id: payment.id,
        organization_id: payment.organization_id,
        plan: payment.plan_type
      }

      case Payments.paystack().checkout(
             scope.user.email,
             Plans.price(plan),
             payment.reference,
             metadata,
             return_url
           ) do
        {:ok, url} ->
          {:ok, payment, url}

        {:error, reason} ->
          gateway_failed(payment, reason)
      end
    end
  end

  @doc """
  Starts an M-Pesa payment: the customer's phone asks for their PIN.
  `callback_url` receives the secret token and returns the public URL Daraja
  will call back.
  """
  @spec start_mpesa(Scope.t(), String.t(), String.t(), (String.t() -> String.t())) ::
          {:ok, Payment.t()} | {:error, term()}
  def start_mpesa(%Scope{} = scope, plan, phone, callback_url)
      when is_function(callback_url, 1) do
    with {:ok, msisdn} <- normalize_phone(phone),
         {:ok, payment} <-
           create_payment(scope, "daraja", plan, %{
             phone: msisdn,
             callback_token: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
           }) do
      push = %{
        phone: msisdn,
        amount: Plans.price(plan),
        reference: payment.reference,
        callback_url: callback_url.(payment.callback_token)
      }

      case Payments.mpesa().stk_push(push) do
        {:ok, %{checkout_request_id: checkout_id, merchant_request_id: merchant_id}} ->
          payment
          |> Payment.update_changeset(%{
            provider_reference: checkout_id,
            provider_payload: %{"merchant_request_id" => merchant_id}
          })
          |> Repo.update()

        {:error, reason} ->
          gateway_failed(payment, reason)
      end
    end
  end

  defp normalize_phone(phone) do
    case Payments.mpesa().normalize_phone(phone) do
      {:ok, msisdn} -> {:ok, msisdn}
      _ -> {:error, :invalid_phone}
    end
  end

  defp create_payment(%Scope{} = scope, provider, plan, extra) do
    with :ok <- Authorization.authorize(scope, :manage, :subscription),
         true <- Plans.paid?(plan) || {:error, :unknown_plan} do
      attrs =
        Map.merge(
          %{
            organization_id: scope.user.organization_id,
            user_id: scope.user.id,
            provider: provider,
            plan_type: plan,
            amount: Plans.price(plan),
            currency: Plans.currency(),
            reference: new_reference()
          },
          extra
        )

      %Payment{} |> Payment.create_changeset(attrs) |> Repo.insert()
    end
  end

  defp new_reference, do: "AF" <> Base.encode32(:crypto.strong_rand_bytes(10), padding: false)

  defp gateway_failed(payment, reason) do
    Logger.warning("payment #{payment.reference} could not start: #{inspect(reason)}")
    fail(payment, "could not start the payment")
    {:error, :gateway}
  end

  ## Reading

  @doc "A payment of the scope's organization, or `nil`."
  def get_payment(%Scope{user: user}, id) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %Payment{organization_id: org} = payment when org == user.organization_id <-
           Repo.get(Payment, id) do
      payment
    else
      _ -> nil
    end
  end

  @doc "Follow a payment: the process receives `{:payment_updated, payment}`."
  def subscribe(%Payment{id: id}), do: Phoenix.PubSub.subscribe(AfyaFit.PubSub, topic(id))

  defp topic(id), do: "payment:#{id}"

  defp broadcast(%Payment{id: id} = payment),
    do: Phoenix.PubSub.broadcast(AfyaFit.PubSub, topic(id), {:payment_updated, payment})

  ## Card: the return page and the webhook

  @doc """
  Called when the customer comes back from Paystack: asks Paystack what became
  of the payment and settles or fails it. Only the organization's own payment is
  visible.
  """
  @spec confirm_card(Scope.t(), String.t()) :: {:ok, Payment.t()} | {:error, term()}
  def confirm_card(%Scope{user: user}, reference) when is_binary(reference) do
    case Repo.get_by(Payment, reference: reference, provider: "paystack") do
      %Payment{organization_id: org, status: "pending"} = payment
      when org == user.organization_id ->
        verify_card(payment)

      %Payment{organization_id: org} = payment when org == user.organization_id ->
        {:ok, payment}

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Asks Paystack what became of a card payment and settles or fails it. A payment
  Paystack still calls open comes back unchanged.
  """
  @spec verify_card(Payment.t()) :: {:ok, Payment.t()} | {:error, :gateway}
  def verify_card(%Payment{} = payment) do
    case Payments.paystack().verify(payment.reference) do
      {:ok, %{status: "success"} = result} ->
        settle_if_matching(payment, result)

      {:ok, %{status: status}} when status in ["failed", "reversed"] ->
        {:ok, fail(payment, "the card payment #{status}")}

      {:ok, _still_open} ->
        {:ok, payment}

      {:error, _reason} ->
        {:error, :gateway}
    end
  end

  @doc """
  A signed `charge.success` event from Paystack. `:unknown` when the reference is
  not one of ours (subscription charges from before this flow).
  """
  @spec paystack_charge_success(map()) :: {:ok, Payment.t()} | :unknown
  def paystack_charge_success(%{"reference" => reference} = data) do
    case Repo.get_by(Payment, reference: reference, provider: "paystack") do
      nil ->
        :unknown

      payment ->
        settle_if_matching(payment, %{
          status: data["status"],
          amount: cents_to_decimal(data["amount"]),
          currency: data["currency"]
        })
    end
  end

  def paystack_charge_success(_data), do: :unknown

  defp cents_to_decimal(cents) when is_integer(cents),
    do: cents |> Decimal.new() |> Decimal.div(100)

  defp cents_to_decimal(_cents), do: Decimal.new(0)

  # Paid means the right amount in the right currency; anything less is refused.
  defp settle_if_matching(payment, %{status: "success"} = result) do
    if result.currency == payment.currency and
         Decimal.compare(result.amount, payment.amount) != :lt do
      settle(payment, %{provider_payload: %{"paid_amount" => Decimal.to_string(result.amount)}})
    else
      {:ok, fail(payment, "amount or currency did not match")}
    end
  end

  defp settle_if_matching(payment, _result), do: {:ok, payment}

  ## Settling

  @doc """
  Marks the payment paid and puts the organization on its plan. Safe to call
  again for the same payment: the second call changes nothing.
  """
  @spec settle(Payment.t(), map()) :: {:ok, Payment.t()}
  def settle(%Payment{id: id}, details \\ %{}) do
    {:ok, {payment, changed?}} =
      Repo.transaction(fn ->
        payment = Repo.one!(from p in Payment, where: p.id == ^id, lock: "FOR UPDATE")

        if payment.status == "succeeded" do
          {payment, false}
        else
          {settle_now(payment, details), true}
        end
      end)

    if changed?, do: broadcast(payment)
    {:ok, payment}
  end

  defp settle_now(payment, details) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    subscription = activate(payment, now)

    {:ok, paid} =
      payment
      |> Payment.update_changeset(
        details
        |> Map.take([:receipt, :provider_payload])
        |> Map.update(
          :provider_payload,
          payment.provider_payload,
          &Map.merge(payment.provider_payload, &1)
        )
        |> Map.merge(%{status: "succeeded", paid_at: now, failure_reason: nil})
      )
      |> Repo.update()

    %Invoice{}
    |> Invoice.changeset(%{
      subscription_id: subscription.id,
      invoice_number: invoice_number(paid, now),
      amount: paid.amount,
      currency: paid.currency,
      status: "paid",
      due_date: DateTime.to_date(now),
      paid_at: now
    })
    |> Repo.insert!()

    Shared.create_activity_log(%{
      organization_id: paid.organization_id,
      user_id: paid.user_id,
      action: "billing.payment",
      resource_type: "payment",
      resource_id: paid.id,
      metadata: %{provider: paid.provider, plan: paid.plan_type, reference: paid.reference}
    })

    paid
  end

  # Paying for the plan you are already on adds a period to the end of the
  # current one; another plan, or a lapsed account, starts a new period.
  defp activate(payment, now) do
    organization = Repo.get!(Organization, payment.organization_id)

    {:ok, subscription} =
      Billing.put_plan(organization, payment.plan_type, Plans.period_days(),
        extend: true,
        now: now
      )

    subscription
  end

  defp invoice_number(payment, now) do
    "INV-#{Calendar.strftime(now, "%Y%m%d")}-#{String.slice(payment.reference, -8, 8)}"
  end

  ## Failing and expiring

  @doc "Marks a pending payment failed. A payment that already settled is left alone."
  @spec fail(Payment.t(), String.t()) :: Payment.t()
  def fail(%Payment{} = payment, reason), do: finish(payment, "failed", reason)

  @doc "Marks a pending payment expired: nobody answered. Money that arrives later still settles it."
  @spec expire(Payment.t()) :: Payment.t()
  def expire(%Payment{} = payment), do: finish(payment, "expired", "no answer from the provider")

  defp finish(%Payment{id: id} = payment, status, reason) do
    {count, rows} =
      Repo.update_all(
        from(p in Payment, where: p.id == ^id and p.status == "pending", select: p),
        set: [status: status, failure_reason: String.slice(reason, 0, 250), updated_at: now()]
      )

    case {count, rows} do
      {1, [updated]} ->
        broadcast(updated)
        updated

      _ ->
        Repo.get!(Payment, payment.id)
    end
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)


end
