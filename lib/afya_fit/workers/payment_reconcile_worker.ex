defmodule AfyaFit.Workers.PaymentReconcileWorker do
  @moduledoc """
  Catches payments whose webhook never arrived: every few minutes it asks the
  provider about each payment that has been pending for over a minute, settles
  or fails it, and expires the ones nobody answered for.
  """
  use Oban.Worker, queue: :default, max_attempts: 1
  use AfyaFit.Repo.Wrap, :job

  alias AfyaFit.Billing.Checkout

  @impl Oban.Worker
  def perform(_job) do
    Enum.each(Checkout.stale_pending(), &Checkout.reconcile/1)
    :ok
  end
end
