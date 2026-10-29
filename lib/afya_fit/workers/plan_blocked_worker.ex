defmodule AfyaFit.Workers.PlanBlockedWorker do
  @moduledoc """
  Emails the support address when an organization is stopped by its plan.

  Unique per organization, kind and feature for a day, including jobs that
  already ran, so repeated blocks produce one email.
  """
  use Oban.Worker,
    queue: :emails,
    max_attempts: 3,
    unique: [
      period: 24 * 60 * 60,
      keys: [:organization_id, :kind, :feature],
      states: [:available, :scheduled, :executing, :retryable, :completed]
    ]

  alias AfyaFit.Mailer
  alias AfyaFitWeb.SupportEmail

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    case Application.get_env(:afya_fit, :support_email) do
      nil ->
        :ok

      address ->
        args |> SupportEmail.plan_blocked(address) |> Mailer.deliver()
        :ok
    end
  end
end
