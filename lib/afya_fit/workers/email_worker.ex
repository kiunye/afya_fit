defmodule AfyaFit.Workers.EmailWorker do
  @moduledoc """
  Oban worker for sending emails via Swoosh.

  Accepts job args with:
  - email_module: String module name (e.g., "AfyaFitWeb.TaskEmail")
  - email_function: String function name (e.g., "task_reminder")
  - args: List of arguments to pass to the email function

  Note: Structs passed in args will be serialized to maps by Oban.
  The email functions should handle maps or structs.
  """
  use Oban.Worker, queue: :emails, max_attempts: 3

  alias AfyaFit.Mailer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"email_module" => email_module, "email_function" => email_function, "args" => args}}) do
    # Convert atom strings back to atoms (e.g., ":seven_days" string -> :seven_days atom)
    processed_args = process_args(args)

    email_module
    |> String.to_existing_atom()
    |> apply(String.to_existing_atom(email_function), processed_args)
    |> Mailer.deliver()

    :ok
  rescue
    e ->
      {:error, Exception.message(e)}
  end

  # Process args to handle JSON deserialization
  # Mainly converts atom strings (like ":seven_days") back to atoms
  defp process_args(args) when is_list(args) do
    Enum.map(args, &process_arg/1)
  end

  defp process_arg(arg) when is_binary(arg) do
    # Try to convert atom strings back to atoms (e.g., ":seven_days" -> :seven_days)
    case arg do
      ":" <> atom_name ->
        String.to_existing_atom(atom_name)
      _ ->
        # Try as regular atom string
        String.to_existing_atom(arg)
    end
  rescue
    ArgumentError -> arg
  end

  defp process_arg(arg) when is_map(arg) do
    # For maps, convert datetime strings and atom strings
    arg
    |> convert_datetime_strings()
    |> convert_atom_strings()
  end

  defp process_arg(arg), do: arg

  # Convert ISO8601 datetime strings back to DateTime structs
  defp convert_datetime_strings(map) do
    datetime_fields = ["due_date", "current_period_end", "current_period_start", "completed_at", "inserted_at", "updated_at"]

    Enum.reduce(datetime_fields, map, fn field, acc ->
      case Map.get(acc, field) do
        nil -> acc
        value when is_binary(value) ->
          case DateTime.from_iso8601(value) do
            {:ok, datetime, _} -> Map.put(acc, field, datetime)
            _ -> acc
          end
        _ -> acc
      end
    end)
  end

  # Convert atom string values back to atoms
  defp convert_atom_strings(map) do
    atom_fields = ["role", "status", "priority", "task_type", "plan_type", "frequency"]

    Enum.reduce(atom_fields, map, fn field, acc ->
      case Map.get(acc, field) do
        nil -> acc
        ":" <> atom_name ->
          try do
            Map.put(acc, field, String.to_existing_atom(atom_name))
          rescue
            ArgumentError -> acc
          end
        value when is_binary(value) ->
          try do
            Map.put(acc, field, String.to_existing_atom(value))
          rescue
            ArgumentError -> acc
          end
        _ -> acc
      end
    end)
  end
end
