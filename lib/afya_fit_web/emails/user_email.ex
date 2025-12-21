defmodule AfyaFitWeb.UserEmail do
  import Swoosh.Email

  @from {"Afya Fit", "noreply@afyafit.com"}

  def confirmation(user, url) do
    new()
    |> to({user.first_name <> " " <> user.last_name, user.email})
    |> from(@from)
    |> subject("Confirm your email address")
    |> html_body(confirmation_html(user, url))
    |> text_body(confirmation_text(user, url))
  end

  def reset_password(user, url) do
    new()
    |> to({user.first_name <> " " <> user.last_name, user.email})
    |> from(@from)
    |> subject("Reset your password")
    |> html_body(reset_password_html(user, url))
    |> text_body(reset_password_text(user, url))
  end

  def change_email(user, url) do
    new()
    |> to({user.first_name <> " " <> user.last_name, user.email})
    |> from(@from)
    |> subject("Confirm your new email address")
    |> html_body(change_email_html(user, url))
    |> text_body(change_email_text(user, url))
  end

  defp confirmation_html(user, url) do
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
        .button { display: inline-block; padding: 12px 24px; background-color: #2563eb; color: #ffffff; text-decoration: none; border-radius: 6px; font-weight: 600; margin: 20px 0; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb; font-size: 12px; color: #6b7280; text-align: center; }
        .link { color: #2563eb; word-break: break-all; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="logo">Afya Fit</div>
        </div>
        <div>
          <h1>Welcome to Afya Fit!</h1>
          <p>Hi #{user.first_name},</p>
          <p>Thank you for signing up! Please confirm your email address by clicking the button below:</p>
          <p style="text-align: center;">
            <a href="#{url}" class="button">Confirm Email Address</a>
          </p>
          <p>Or copy and paste this link into your browser:</p>
          <p><a href="#{url}" class="link">#{url}</a></p>
          <p>This link will expire in 24 hours.</p>
          <p>If you didn't create an account with us, please ignore this email.</p>
        </div>
        <div class="footer">
          <p>If you didn't request this email, you can safely ignore it.</p>
          <p>&copy; #{DateTime.utc_now().year} Afya Fit. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp confirmation_text(user, url) do
    """
    Welcome to Afya Fit!

    Hi #{user.first_name},

    Thank you for signing up! Please confirm your email address by visiting:

    #{url}

    This link will expire in 24 hours.

    If you didn't create an account with us, please ignore this email.
    """
  end

  defp reset_password_html(user, url) do
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
        .button { display: inline-block; padding: 12px 24px; background-color: #2563eb; color: #ffffff; text-decoration: none; border-radius: 6px; font-weight: 600; margin: 20px 0; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb; font-size: 12px; color: #6b7280; text-align: center; }
        .link { color: #2563eb; word-break: break-all; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="logo">Afya Fit</div>
        </div>
        <div>
          <h1>Reset Your Password</h1>
          <p>Hi #{user.first_name},</p>
          <p>We received a request to reset your password. Click the button below to create a new password:</p>
          <p style="text-align: center;">
            <a href="#{url}" class="button">Reset Password</a>
          </p>
          <p>Or copy and paste this link into your browser:</p>
          <p><a href="#{url}" class="link">#{url}</a></p>
          <p>This link will expire in 1 hour.</p>
          <p>If you didn't request a password reset, please ignore this email. Your password will remain unchanged.</p>
        </div>
        <div class="footer">
          <p>If you didn't request this email, you can safely ignore it.</p>
          <p>&copy; #{DateTime.utc_now().year} Afya Fit. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp reset_password_text(user, url) do
    """
    Reset Your Password

    Hi #{user.first_name},

    We received a request to reset your password. Visit the link below to create a new password:

    #{url}

    This link will expire in 1 hour.

    If you didn't request a password reset, please ignore this email. Your password will remain unchanged.
    """
  end

  defp change_email_html(user, url) do
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
        .button { display: inline-block; padding: 12px 24px; background-color: #2563eb; color: #ffffff; text-decoration: none; border-radius: 6px; font-weight: 600; margin: 20px 0; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb; font-size: 12px; color: #6b7280; text-align: center; }
        .link { color: #2563eb; word-break: break-all; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="logo">Afya Fit</div>
        </div>
        <div>
          <h1>Confirm Your New Email Address</h1>
          <p>Hi #{user.first_name},</p>
          <p>You requested to change your email address. Please confirm your new email by clicking the button below:</p>
          <p style="text-align: center;">
            <a href="#{url}" class="button">Confirm New Email</a>
          </p>
          <p>Or copy and paste this link into your browser:</p>
          <p><a href="#{url}" class="link">#{url}</a></p>
          <p>This link will expire in 24 hours.</p>
          <p>If you didn't request this change, please contact our support team immediately.</p>
        </div>
        <div class="footer">
          <p>If you didn't request this email, you can safely ignore it.</p>
          <p>&copy; #{DateTime.utc_now().year} Afya Fit. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp change_email_text(user, url) do
    """
    Confirm Your New Email Address

    Hi #{user.first_name},

    You requested to change your email address. Please confirm your new email by visiting:

    #{url}

    This link will expire in 24 hours.

    If you didn't request this change, please contact our support team immediately.
    """
  end
end
