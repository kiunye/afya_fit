defmodule AfyaFitWeb.API.TaskController do
  use AfyaFitWeb, :controller

  alias AfyaFit.{Accounts, Authorization, Tasks}
  alias AfyaFit.Authorization.Scope

  # Authentication is handled in router pipeline

  action_fallback AfyaFitWeb.API.FallbackController

  # Ownership of a task cannot be changed through the API.
  @protected_fields ["organization_id", "trainer_id", "client_id"]

  def index(conn, _params) do
    scope = conn.assigns.current_scope

    with :ok <- Authorization.authorize(scope, :list, :task) do
      render(conn, :index, tasks: Tasks.list_tasks_for(scope))
    end
  end

  def create(conn, %{"task" => task_params}) do
    scope = conn.assigns.current_scope

    with {:ok, attrs} <- build_task(scope, task_params),
         {:ok, task} <- Tasks.create_task(attrs) do
      conn
      |> put_status(:created)
      |> render(:show, task: task)
    end
  end

  def show(conn, %{"id" => id}) do
    task = Tasks.get_task!(id)

    with :ok <- Authorization.authorize(conn.assigns.current_scope, :read, task) do
      render(conn, :show, task: task)
    end
  end

  def update(conn, %{"id" => id, "task" => task_params}) do
    scope = conn.assigns.current_scope
    task = Tasks.get_task!(id)
    attrs = Map.drop(task_params, @protected_fields)

    with :ok <- Authorization.authorize(scope, :update, task),
         :ok <- authorize_automation(scope, attrs),
         {:ok, task} <- Tasks.update_task(task, attrs) do
      render(conn, :show, task: task)
    end
  end

  def delete(conn, %{"id" => id}) do
    task = Tasks.get_task!(id)

    with :ok <- Authorization.authorize(conn.assigns.current_scope, :delete, task),
         {:ok, _task} <- Tasks.delete_task(task) do
      send_resp(conn, :no_content, "")
    end
  end

  def complete(conn, %{"id" => id}) do
    task = Tasks.get_task!(id)
    attrs = %{"status" => "completed", "completed_at" => DateTime.utc_now()}

    with :ok <- Authorization.authorize(conn.assigns.current_scope, :complete, task),
         {:ok, task} <- Tasks.update_task(task, attrs) do
      render(conn, :show, task: task)
    end
  end

  def client_tasks(conn, %{"client_id" => client_id}) do
    scope = conn.assigns.current_scope
    client = Accounts.get_user!(client_id)

    with :ok <- Authorization.authorize(scope, :read, client),
         :ok <- Authorization.authorize(scope, :list, :task) do
      render(conn, :index, tasks: Tasks.list_client_tasks(client))
    end
  end

  def bulk(conn, %{"tasks" => tasks_params}) do
    scope = conn.assigns.current_scope

    with :ok <- Authorization.authorize(scope, :create, :task) do
      results =
        Enum.map(tasks_params, fn task_params ->
          with {:ok, attrs} <- build_task(scope, task_params) do
            Tasks.create_task(attrs)
          end
        end)

      successful = Enum.filter(results, &match?({:ok, _}, &1))

      json(conn, %{
        created: length(successful),
        failed: length(results) - length(successful),
        results: Enum.map(results, &format_result/1)
      })
    end
  end

  # A task is created for a client the requester coaches, and recurring tasks
  # need the automation feature.
  defp build_task(scope, params) do
    attrs =
      params
      |> Map.put("organization_id", scope.user.organization_id)
      |> Map.put("trainer_id", scope.user.id)

    with :ok <- Authorization.authorize(scope, :create, :task),
         :ok <- authorize_automation(scope, attrs),
         :ok <- authorize_client(scope, attrs["client_id"]) do
      {:ok, attrs}
    end
  end

  defp authorize_automation(scope, %{"is_recurring" => recurring})
       when recurring in [true, "true"],
       do: Authorization.authorize(scope, :automate, :task)

  defp authorize_automation(_scope, _attrs), do: :ok

  defp authorize_client(scope, client_id) do
    if Scope.manages_client?(scope, client_id), do: :ok, else: {:error, :forbidden}
  end

  defp format_result({:ok, task}), do: %{status: "success", id: task.id}

  defp format_result({:error, %Ecto.Changeset{} = changeset}),
    do: %{status: "error", errors: translate_errors(changeset)}

  defp format_result({:error, reason}), do: %{status: "error", reason: error_reason(reason)}

  defp error_reason({:upgrade_required, %{feature: feature}}), do: "upgrade_required:#{feature}"
  defp error_reason({:subscription_inactive, _status}), do: "subscription_inactive"
  defp error_reason(reason), do: to_string(reason)

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
