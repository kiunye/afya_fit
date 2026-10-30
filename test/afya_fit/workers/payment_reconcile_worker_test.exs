defmodule AfyaFit.Workers.PaymentReconcileWorkerTest do
  use AfyaFit.DataCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Billing.{Checkout, Payment}
  alias AfyaFit.Repo
  alias AfyaFit.Test.FakeGateways
  alias AfyaFit.Workers.PaymentReconcileWorker

  test "settles a stale M-Pesa payment and leaves a fresh one alone" do
    scope = organization() |> user(:org_admin) |> Scope.load()
    url = &"https://afyafit.test/webhooks/mpesa/#{&1}"

    {:ok, stale} = Checkout.start_mpesa(scope, "pro", "0712345678", url)
    {:ok, fresh} = Checkout.start_mpesa(scope, "pro", "0722345678", url)
    at = DateTime.add(DateTime.utc_now(), -5, :minute) |> DateTime.truncate(:second)
    Repo.update_all(from(p in Payment, where: p.id == ^stale.id), set: [inserted_at: at])

    for payment <- [stale, fresh],
        do:
          FakeGateways.set_query(
            payment.provider_reference,
            {:ok, %{result_code: 0, description: "ok"}}
          )

    assert :ok = PaymentReconcileWorker.perform(%Oban.Job{})

    assert Repo.get!(Payment, stale.id).status == "succeeded"
    assert Repo.get!(Payment, fresh.id).status == "pending"
  end

  test "is on the schedule" do
    crontab =
      :afya_fit
      |> Application.fetch_env!(Oban)
      |> Keyword.fetch!(:plugins)
      |> Keyword.fetch!(Oban.Plugins.Cron)
      |> Keyword.fetch!(:crontab)

    assert {"*/5 * * * *", PaymentReconcileWorker} in crontab
  end
end
