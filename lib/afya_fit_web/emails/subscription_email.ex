defmodule AfyaFitWeb.SubscriptionEmail do
  import Swoosh.Email

  @from {"Afya Fit", "noreply@afyafit.com"}

  def renewal_reminder(user, subscription, days) do
    days_text =
      case days do
        :seven_days -> "7 days"
        :three_days -> "3 days"
        _ -> "#{days} days"
      end

    new()
    |> to({user.first_name <> " " <> user.last_name, user.email})
    |> from(@from)
    |> subject("Subscription Renewal Reminder - #{days_text} remaining")
    |> html_body(renewal_reminder_html(user, subscription, days))
    |> text_body(renewal_reminder_text(user, subscription, days))
  end

  defp renewal_reminder_html(user, subscription, days) do
    period_end_str =
      subscription.current_period_end
      |> DateTime.to_date()
      |> Date.to_string()

    urgency_class =
      if days == :three_days, do: "color: #dc2626; font-weight: bold;", else: "color: #f59e0b;"

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f5f5f5; }
        .container { background-color: #ffffff; border-radius: 8px; padding: 40px; box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .logo { font-size: 28px; font-weight: bold; color: #2563eb; margin-bottom: 10px; }
        h1 { color: #1f2937; font-size: 24px; margin-bottom: 16px; }
        p { margin-bottom: 12px; color: #4b5563; }
        .subscription-details { background-color: #f9fafb; border-left: 4px solid #2563eb; padding: 16px; margin: 20px 0; border-radius: 4px; }
        .subscription-title { font-size: 18px; font-weight: 600; color: #1f2937; margin-bottom: 8px; }
        .subscription-meta { font-size: 14px; color: #6b7280; }
        .button { display: inline-block; padding: 12px 24px; background-color: #2563eb; color: #ffffff; text-decoration: none; border-radius: 6px; font-weight: 600; margin: 20px 0; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb; font-size: 12px; color: #6b7280; text-align: center; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="logo">Afya Fit</div>
        </div>
        <div>
          <h1>Subscription Renewal Reminder</h1>
          <p>Hi #{user.first_name},</p>
          <p>This is a reminder that your subscription will expire soon:</p>
          <div class="subscription-details">
            <div class="subscription-title">#{String.capitalize(subscription.plan_type)} Plan</div>
            <div class="subscription-meta" style="#{urgency_class}">
              <strong>Expires:</strong> #{period_end_str}
            </div>
            <div class="subscription-meta">
              <strong>Status:</strong> #{String.capitalize(subscription.status)}
            </div>
          </div>
          <p>Please renew your subscription to continue enjoying all features of Afya Fit.</p>
          <a href="#" class="button">Renew Subscription</a>
        </div>
        <div class="footer">
          <p>&copy; #{DateTime.utc_now().year} Afya Fit. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp renewal_reminder_text(user, subscription, days) do
    period_end_str =
      subscription.current_period_end
      |> DateTime.to_date()
      |> Date.to_string()

    days_text =
      case days do
        :seven_days -> "7 days"
        :three_days -> "3 days"
        _ -> "#{days} days"
      end

    """
    Subscription Renewal Reminder

    Hi #{user.first_name},

    This is a reminder that your subscription will expire in #{days_text}:

    Plan: #{String.capitalize(subscription.plan_type)}
    Expires: #{period_end_str}
    Status: #{String.capitalize(subscription.status)}

    Please renew your subscription to continue enjoying all features of Afya Fit.
    """
  end
end
