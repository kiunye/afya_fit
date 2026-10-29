defmodule AfyaFit.Workers.ClientSubscriptionReminderWorker do
  @moduledoc """
  Oban worker for sending client subscription expiry reminder emails.
  """
  use Oban.Worker, queue: :default, max_attempts: 3
  use AfyaFit.Repo.Wrap, :job

  alias AfyaFit.{Accounts, Billing, Organizations}
  alias AfyaFitWeb.Emails

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"client_subscription_id" => client_id, "days_until_expiry" => days}}) do
    subscription = Billing.get_client_subscription_by_client(client_id)

    if subscription && subscription.status == "active" do
      client = Accounts.get_user!(subscription.client_id)
      organization = Organizations.get_organization!(subscription.organization_id)

      # Check reminder preferences
      prefs = subscription.reminder_preferences || %{}
      enabled = Map.get(prefs, "enabled", true)
      days_before = Map.get(prefs, "days_before_expiry", [7, 3, 1])

      if enabled && days in days_before do
        email = AfyaFitWeb.ClientSubscriptionEmail.expiry_reminder(
          client,
          organization,
          subscription,
          days
        )
        AfyaFitWeb.Mailer.deliver(email)
      end
    end

    :ok
  end

  @doc """
  Schedules reminder emails for expiring client subscriptions.
  """
  def schedule_reminders do
    # Get subscriptions expiring in the next 7 days
    expiring_subscriptions = Billing.list_expiring_client_subscriptions(7)

    for subscription <- expiring_subscriptions do
      days_until_expiry =
        DateTime.diff(subscription.current_period_end, DateTime.utc_now(), :day)

      # Schedule reminders for 7, 3, and 1 days before expiry
      for days <- [7, 3, 1] do
        if days_until_expiry <= days && days_until_expiry > 0 do
          %{
            client_subscription_id: subscription.client_id,
            days_until_expiry: days
          }
          |> new()
          |> Oban.insert()
        end
      end
    end
  end
end
