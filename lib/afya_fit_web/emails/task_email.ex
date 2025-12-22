defmodule AfyaFitWeb.TaskEmail do
  import Swoosh.Email

  @from {"Afya Fit", "noreply@afyafit.com"}

  def task_reminder(user, task) do
    new()
    |> to({user.first_name <> " " <> user.last_name, user.email})
    |> from(@from)
    |> subject("Task Reminder: #{task.title}")
    |> html_body(task_reminder_html(user, task))
    |> text_body(task_reminder_text(user, task))
  end

  defp task_reminder_html(user, task) do
    due_date_str =
      if task.due_date do
        task.due_date
        |> DateTime.to_date()
        |> Date.to_string()
      else
        "No due date"
      end

    is_overdue =
      if task.due_date do
        DateTime.compare(task.due_date, DateTime.utc_now()) == :lt
      else
        false
      end

    overdue_class = if is_overdue, do: "color: #dc2626; font-weight: bold;", else: ""

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
        .task-details { background-color: #f9fafb; border-left: 4px solid #2563eb; padding: 16px; margin: 20px 0; border-radius: 4px; }
        .task-title { font-size: 18px; font-weight: 600; color: #1f2937; margin-bottom: 8px; }
        .task-meta { font-size: 14px; color: #6b7280; }
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
          <h1>Task Reminder</h1>
          <p>Hi #{user.first_name},</p>
          <p>This is a reminder about your upcoming task:</p>
          <div class="task-details">
            <div class="task-title">#{task.title}</div>
            #{if task.description, do: "<p style=\"margin-top: 8px; color: #4b5563;\">#{task.description}</p>", else: ""}
            <div class="task-meta" style="#{overdue_class}">
              <strong>Due Date:</strong> #{due_date_str}
              #{if is_overdue, do: " (Overdue)", else: ""}
            </div>
            <div class="task-meta">
              <strong>Priority:</strong> #{String.capitalize(task.priority || "medium")}
            </div>
            <div class="task-meta">
              <strong>Type:</strong> #{String.capitalize(task.task_type || "custom")}
            </div>
          </div>
          <p>Please complete this task before the due date.</p>
        </div>
        <div class="footer">
          <p>&copy; #{DateTime.utc_now().year} Afya Fit. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
    """
  end

  defp task_reminder_text(user, task) do
    due_date_str =
      if task.due_date do
        task.due_date
        |> DateTime.to_date()
        |> Date.to_string()
      else
        "No due date"
      end

    is_overdue =
      if task.due_date do
        DateTime.compare(task.due_date, DateTime.utc_now()) == :lt
      else
        false
      end

    overdue_text = if is_overdue, do: " (OVERDUE)", else: ""

    """
    Task Reminder

    Hi #{user.first_name},

    This is a reminder about your upcoming task:

    Title: #{task.title}
    #{if task.description, do: "Description: #{task.description}\n", else: ""}
    Due Date: #{due_date_str}#{overdue_text}
    Priority: #{String.capitalize(task.priority || "medium")}
    Type: #{String.capitalize(task.task_type || "custom")}

    Please complete this task before the due date.
    """
  end
end
