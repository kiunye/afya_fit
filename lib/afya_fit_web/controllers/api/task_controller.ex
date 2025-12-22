defmodule AfyaFitWeb.API.TaskController do
  use AfyaFitWeb, :controller

  alias AfyaFit.{Clients, Tasks}

  # Authentication is handled in router pipeline

  action_fallback AfyaFitWeb.API.FallbackController

  def index(conn, _params) do
    current_user = conn.assigns.current_user

    tasks =
      case current_user.role do
        "trainer" ->
          # Trainers see tasks for their clients
          Tasks.list_tasks(nil)
          |> Enum.filter(fn task ->
            task.organization_id == current_user.organization_id &&
              task.trainer_id == current_user.id
          end)

        "client" ->
          # Clients see their own tasks
          Tasks.list_tasks(current_user.id)

        "admin" ->
          Tasks.list_tasks(nil)
          |> Enum.filter(fn task ->
            task.organization_id == current_user.organization_id
          end)
      end

    render(conn, :index, tasks: tasks)
  end

  def create(conn, %{"task" => task_params}) do
    current_user = conn.assigns.current_user

    attrs =
      task_params
      |> Map.put("organization_id", current_user.organization_id)
      |> Map.put("trainer_id", current_user.id)

    # Verify client access if client_id is provided
    if client_id = Map.get(attrs, "client_id") do
      unless Clients.trainer_has_client?(current_user.id, client_id) do
        conn
        |> put_status(:forbidden)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"403")
        |> halt()
      end
    end

    case Tasks.create_task(attrs) do
      {:ok, task} ->
        conn
        |> put_status(:created)
        |> render(:show, task: task)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"422", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    task = Tasks.get_task!(id)

    # Verify access
    if task.organization_id == current_user.organization_id &&
         (task.trainer_id == current_user.id || task.client_id == current_user.id ||
            current_user.role == "admin") do
      render(conn, :show, task: task)
    else
      conn
      |> put_status(:forbidden)
      |> put_view(AfyaFitWeb.API.ErrorView)
      |> render(:"403")
    end
  end

  def update(conn, %{"id" => id, "task" => task_params}) do
    current_user = conn.assigns.current_user
    task = Tasks.get_task!(id)

    # Verify ownership or client can update their own tasks
    if task.trainer_id == current_user.id || task.client_id == current_user.id ||
         current_user.role == "admin" do
      case Tasks.update_task(task, task_params) do
        {:ok, task} ->
          render(conn, :show, task: task)

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(AfyaFitWeb.API.ErrorView)
          |> render(:"422", changeset: changeset)
      end
    else
      conn
      |> put_status(:forbidden)
      |> put_view(AfyaFitWeb.API.ErrorView)
      |> render(:"403")
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    task = Tasks.get_task!(id)

    # Verify ownership
    if task.trainer_id == current_user.id || current_user.role == "admin" do
      Tasks.delete_task(task)
      send_resp(conn, :no_content, "")
    else
      conn
      |> put_status(:forbidden)
      |> put_view(AfyaFitWeb.API.ErrorView)
      |> render(:"403")
    end
  end

  def complete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    task = Tasks.get_task!(id)

    # Verify access
    if task.client_id == current_user.id || task.trainer_id == current_user.id ||
         current_user.role == "admin" do
      attrs = %{
        "status" => "completed",
        "completed_at" => DateTime.utc_now()
      }

      case Tasks.update_task(task, attrs) do
        {:ok, task} ->
          render(conn, :show, task: task)

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(AfyaFitWeb.API.ErrorView)
          |> render(:"422", changeset: changeset)
      end
    else
      conn
      |> put_status(:forbidden)
      |> put_view(AfyaFitWeb.API.ErrorView)
      |> render(:"403")
    end
  end

  def client_tasks(conn, %{"client_id" => client_id}) do
    current_user = conn.assigns.current_user

    # Verify client access
    if current_user.role == "trainer" do
      Clients.get_client!(current_user, client_id)
    end

    tasks = Tasks.list_tasks(client_id)

    render(conn, :index, tasks: tasks)
  end

  def bulk(conn, %{"tasks" => tasks_params}) do
    current_user = conn.assigns.current_user

    results =
      Enum.map(tasks_params, fn task_params ->
        attrs =
          task_params
          |> Map.put("organization_id", current_user.organization_id)
          |> Map.put("trainer_id", current_user.id)

        Tasks.create_task(attrs)
      end)

    successful = Enum.filter(results, fn {status, _} -> status == :ok end)
    failed = Enum.filter(results, fn {status, _} -> status == :error end)

    json(conn, %{
      created: length(successful),
      failed: length(failed),
      results: Enum.map(results, &format_result/1)
    })
  end

  defp format_result({:ok, task}), do: %{status: "success", id: task.id}

  defp format_result({:error, changeset}),
    do: %{status: "error", errors: translate_errors(changeset)}

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
