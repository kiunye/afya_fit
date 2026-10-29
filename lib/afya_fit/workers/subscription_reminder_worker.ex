defmodule AfyaFit.Workers.SubscriptionReminderWorker do
  @moduledoc """
  Oban worker for sending subscription renewal reminders.
  Runs daily to check for subscriptions expiring soon and send reminders.
  """
  use Oban.Worker, queue: :tasks, max_attempts: 3
  use AfyaFit.Repo.Wrap, :job

  import Ecto.Query
  alias AfyaFit.Billing.Subscription
  alias AfyaFit.Organizations
  alias AfyaFit.Repo
  alias AfyaFit.Workers.EmailWorker

  @impl Oban.Worker
  def perform(_job) do
    today = DateTime.utc_now()
    seven_days_from_now = DateTime.add(today, 7 * 24 * 60 * 60, :second)
    three_days_from_now = DateTime.add(today, 3 * 24 * 60 * 60, :second)

    # Find subscriptions expiring in 7 days
    expiring_soon =
      Subscription
      |> where([s], s.status == "active")
      |> where([s], s.current_period_end >= ^today)
      |> where([s], s.current_period_end <= ^seven_days_from_now)
      |> where([s], s.current_period_end > ^three_days_from_now)
      |> preload([:organization])
      |> Repo.all()

    Enum.each(expiring_soon, fn subscription ->
      send_subscription_reminder(subscription, :seven_days)
    end)

    # Find subscriptions expiring in 3 days
    expiring_very_soon =
      Subscription
      |> where([s], s.status == "active")
      |> where([s], s.current_period_end >= ^today)
      |> where([s], s.current_period_end <= ^three_days_from_now)
      |> preload([:organization])
      |> Repo.all()

    Enum.each(expiring_very_soon, fn subscription ->
      send_subscription_reminder(subscription, :three_days)
    end)

    :ok
  end

  defp send_subscription_reminder(%Subscription{} = subscription, days) do
    # Get organization owner/admin to send reminder to
    organization = Organizations.get_organization!(subscription.organization_id)
    owner = Organizations.get_organization_owner(organization)

    if owner do
      %{
        "email_module" => "AfyaFitWeb.SubscriptionEmail",
        "email_function" => "renewal_reminder",
        "args" => [owner, subscription, days]
      }
      |> EmailWorker.new()
      |> Oban.insert()
    end
  end
end
