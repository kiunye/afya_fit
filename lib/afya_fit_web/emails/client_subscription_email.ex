defmodule AfyaFitWeb.ClientSubscriptionEmail do
  import Swoosh.Email

  @from {"Afya Fit", "noreply@afyafit.com"}

  def expiry_reminder(client, organization, subscription, days) do
    new()
    |> to({client.first_name <> " " <> client.last_name, client.email})
    |> from(@from)
    |> subject("Subscription Expiry Reminder - #{days} days remaining")
    |> html_body(expiry_reminder_html(client, organization, subscription, days))
    |> text_body(expiry_reminder_text(client, organization, subscription, days))
  end

  defp expiry_reminder_html(client, organization, subscription, days) do
    period_end_str =
      subscription.current_period_end
      |> DateTime.to_date()
      |> Date.to_string()

    urgency_class =
      if days <= 1, do: "color: #dc2626; font-weight: bold;", else: "color: #f59e0b;"

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #2563eb; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background: #f9fafb; }
        .footer { text-align: center; padding: 20px; color: #6b7280; font-size: 12px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>Afya Fit</h1>
        </div>
        <div class="content">
          <h2>Subscription Expiry Reminder</h2>
          <p>Hi #{client.first_name},</p>
          <p>Your subscription with <strong>#{organization.name}</strong> will expire in <strong style="#{urgency_class}">#{days} #{if days == 1, do: "day", else: "days"}</strong>.</p>
          <div style="background: white; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <p><strong>Expiry Date:</strong> #{period_end_str}</p>
            <p><strong>Plan Type:</strong> #{String.capitalize(subscription.plan_type)}</p>
          </div>
          <p>Please renew your subscription to continue enjoying our services.</p>
          <p style="margin-top: 20px;">
            <a href="#" style="background: #2563eb; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">Renew Subscription</a>
          </p>
        </div>
        <div class="footer">
          <p>&copy; #{DateTime.utc_now().year} Afya Fit. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp expiry_reminder_text(client, organization, subscription, days) do
    period_end_str =
      subscription.current_period_end
      |> DateTime.to_date()
      |> Date.to_string()

    """
    Subscription Expiry Reminder

    Hi #{client.first_name},

    Your subscription with #{organization.name} will expire in #{days} #{if days == 1, do: "day", else: "days"}.

    Expiry Date: #{period_end_str}
    Plan Type: #{String.capitalize(subscription.plan_type)}

    Please renew your subscription to continue enjoying our services.
    """
  end
end
