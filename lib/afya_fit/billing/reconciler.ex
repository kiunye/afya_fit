defmodule AfyaFit.Billing.Reconciler do
  @moduledoc """
  Looks at pending payments again, to catch webhooks that never arrived: asks the
  provider what became of each one, settles or fails it, and expires the ones
  nobody has answered for too long (15 minutes for an M-Pesa prompt, a day for a
  card checkout). Run every few minutes by `AfyaFit.Workers.PaymentReconcileWorker`.
  """

  import Ecto.Query

  alias AfyaFit.Billing.{Checkout, Payment}
  alias AfyaFit.{Payments, Repo}

  @expire_after %{"paystack" => 24 * 3600, "daraja" => 15 * 60}

  @doc "Pending payments old enough that their webhook should have arrived."
  @spec stale_pending(non_neg_integer()) :: [Payment.t()]
  def stale_pending(older_than_seconds \\ 60) do
    cutoff = DateTime.add(DateTime.utc_now(), -older_than_seconds, :second)

    Repo.all(
      from p in Payment,
        where: p.status == "pending" and p.inserted_at < ^cutoff,
        order_by: [asc: p.inserted_at],
        limit: 200
    )
  end

  @doc "Settles, fails or expires a pending payment, or leaves it pending. Others are returned as they are."
  @spec reconcile(Payment.t(), DateTime.t()) :: Payment.t()
  def reconcile(payment, now \\ DateTime.utc_now())

  def reconcile(%Payment{status: "pending"} = payment, now) do
    case ask_provider(payment) do
      {:done, updated} ->
        updated

      :open ->
        if DateTime.diff(now, payment.inserted_at) > Map.fetch!(@expire_after, payment.provider),
          do: Checkout.expire(payment),
          else: payment
    end
  end

  def reconcile(%Payment{} = payment, _now), do: payment

  defp ask_provider(%Payment{provider: "daraja", provider_reference: checkout_id} = payment)
       when is_binary(checkout_id) do
    case Payments.mpesa().stk_query(checkout_id) do
      {:ok, %{result_code: 0}} ->
        {:ok, settled} = Checkout.settle(payment)
        {:done, settled}

      {:ok, %{result_code: code, description: description}} when is_integer(code) ->
        {:done, Checkout.fail(payment, description || "the payment was not completed")}

      _no_answer_yet ->
        :open
    end
  end

  defp ask_provider(%Payment{provider: "paystack"} = payment) do
    case Checkout.verify_card(payment) do
      {:ok, %Payment{status: "pending"}} -> :open
      {:ok, updated} -> {:done, updated}
      {:error, _reason} -> :open
    end
  end

  defp ask_provider(_payment), do: :open
end
