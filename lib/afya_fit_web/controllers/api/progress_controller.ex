defmodule AfyaFitWeb.API.ProgressController do
  use AfyaFitWeb, :controller

  alias AfyaFit.{Clients, Tracking}

  # Authentication is handled in router pipeline

  action_fallback AfyaFitWeb.API.FallbackController

  def index(conn, %{"client_id" => client_id}) do
    current_user = conn.assigns.current_user

    # Verify client access
    if current_user.role == "trainer" do
      Clients.get_client!(current_user, client_id)
    end

    progress_entries = Tracking.list_progress_entries(client_id)

    # Verify entries belong to user's organization
    filtered_entries =
      Enum.filter(progress_entries, fn entry ->
        entry.trainer_id == current_user.id || current_user.role == "admin"
      end)

    render(conn, :index, progress_entries: filtered_entries)
  end

  def create(conn, %{"client_id" => client_id, "progress_entry" => progress_params}) do
    current_user = conn.assigns.current_user

    # Verify client access
    if current_user.role == "trainer" do
      Clients.get_client!(current_user, client_id)
    end

    attrs =
      progress_params
      |> Map.put("client_id", client_id)
      |> Map.put("trainer_id", current_user.id)

    case Tracking.create_progress_entry(attrs) do
      {:ok, progress_entry} ->
        conn
        |> put_status(:created)
        |> render(:show, progress_entry: progress_entry)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(AfyaFitWeb.API.ErrorView)
        |> render(:"422", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    progress_entry = Tracking.get_progress_entry!(id)

    # Verify access - progress entries don't have organization_id, check via trainer/client
    if progress_entry.trainer_id == current_user.id ||
         progress_entry.client_id == current_user.id || current_user.role == "admin" do
      render(conn, :show, progress_entry: progress_entry)
    else
      conn
      |> put_status(:forbidden)
      |> put_view(AfyaFitWeb.API.ErrorView)
      |> render(:"403")
    end
  end

  def update(conn, %{"id" => id, "progress_entry" => progress_params}) do
    current_user = conn.assigns.current_user
    progress_entry = Tracking.get_progress_entry!(id)

    # Verify ownership
    if progress_entry.trainer_id == current_user.id || current_user.role == "admin" do
      case Tracking.update_progress_entry(progress_entry, progress_params) do
        {:ok, progress_entry} ->
          render(conn, :show, progress_entry: progress_entry)

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
    progress_entry = Tracking.get_progress_entry!(id)

    # Verify ownership
    if progress_entry.trainer_id == current_user.id || current_user.role == "admin" do
      Tracking.delete_progress_entry(progress_entry)
      send_resp(conn, :no_content, "")
    else
      conn
      |> put_status(:forbidden)
      |> put_view(AfyaFitWeb.API.ErrorView)
      |> render(:"403")
    end
  end

  def analytics(conn, %{"client_id" => client_id}) do
    current_user = conn.assigns.current_user

    # Verify client access
    if current_user.role == "trainer" do
      Clients.get_client!(current_user, client_id)
    end

    progress_entries = Tracking.list_progress_entries(client_id)

    # Calculate analytics
    analytics = %{
      total_entries: length(progress_entries),
      weight_change: calculate_weight_change(progress_entries),
      body_fat_change: calculate_body_fat_change(progress_entries),
      entries_by_month: group_by_month(progress_entries)
    }

    json(conn, analytics)
  end

  defp calculate_weight_change(entries) do
    sorted = Enum.sort_by(entries, & &1.entry_date, {:asc, Date})

    case sorted do
      [] ->
        nil

      [first | _] = all ->
        last = List.last(all)
        if first.weight && last.weight, do: last.weight - first.weight, else: nil
    end
  end

  defp calculate_body_fat_change(entries) do
    sorted = Enum.sort_by(entries, & &1.entry_date, {:asc, Date})

    case sorted do
      [] ->
        nil

      [first | _] = all ->
        last = List.last(all)

        if first.body_fat_percentage && last.body_fat_percentage,
          do: last.body_fat_percentage - first.body_fat_percentage,
          else: nil
    end
  end

  defp group_by_month(entries) do
    entries
    |> Enum.group_by(fn entry ->
      {entry.entry_date.year, entry.entry_date.month}
    end)
    |> Map.new(fn {key, values} -> {key, length(values)} end)
  end
end
