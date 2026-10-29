defmodule AfyaFitWeb.API.ProgressController do
  use AfyaFitWeb, :controller

  alias AfyaFit.{Authorization, Clients, Tracking}

  # Authentication is handled in router pipeline

  action_fallback AfyaFitWeb.API.FallbackController

  # Ownership of an entry cannot be changed through the API.
  @protected_fields ["client_id", "trainer_id"]

  def index(conn, %{"client_id" => client_id}) do
    scope = conn.assigns.current_scope

    with {:ok, _client} <- Clients.fetch_for(scope, :read, client_id),
         :ok <- Authorization.authorize(scope, :list, :progress_entry) do
      render(conn, :index, progress_entries: Tracking.list_progress_entries(client_id))
    end
  end

  def create(conn, %{"client_id" => client_id, "progress_entry" => progress_params}) do
    scope = conn.assigns.current_scope

    with {:ok, client} <- Clients.fetch_for(scope, :read, client_id),
         :ok <- Authorization.authorize(scope, :create, :progress_entry),
         attrs = new_entry_attrs(scope, client, progress_params),
         {:ok, progress_entry} <- Tracking.create_progress_entry(attrs) do
      conn
      |> put_status(:created)
      |> render(:show, progress_entry: progress_entry)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, progress_entry} <- fetch_entry(conn, :read, id) do
      render(conn, :show, progress_entry: progress_entry)
    end
  end

  def update(conn, %{"id" => id, "progress_entry" => progress_params}) do
    with {:ok, progress_entry} <- fetch_entry(conn, :update, id),
         {:ok, progress_entry} <-
           Tracking.update_progress_entry(
             progress_entry,
             Map.drop(progress_params, @protected_fields)
           ) do
      render(conn, :show, progress_entry: progress_entry)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, progress_entry} <- fetch_entry(conn, :delete, id),
         {:ok, _progress_entry} <- Tracking.delete_progress_entry(progress_entry) do
      send_resp(conn, :no_content, "")
    end
  end

  def analytics(conn, %{"client_id" => client_id}) do
    scope = conn.assigns.current_scope

    with {:ok, _client} <- Clients.fetch_for(scope, :read, client_id),
         :ok <- Authorization.authorize(scope, :analytics, :progress_entry) do
      progress_entries = Tracking.list_progress_entries(client_id)

      json(conn, %{
        total_entries: length(progress_entries),
        weight_change: calculate_weight_change(progress_entries),
        body_fat_change: calculate_body_fat_change(progress_entries),
        entries_by_month: group_by_month(progress_entries)
      })
    end
  end

  # Entries carry no organization of their own, so the client is preloaded.
  defp fetch_entry(conn, action, id) do
    entry = id |> Tracking.get_progress_entry!() |> AfyaFit.Repo.preload(:client)

    with :ok <- Authorization.authorize(conn.assigns.current_scope, action, entry) do
      {:ok, entry}
    end
  end

  # Entries record the coach: the requester for coaches, the linked trainer for clients.
  defp new_entry_attrs(scope, client, params) do
    trainer_id =
      if Authorization.Scope.role(scope) == :client,
        do: Clients.primary_trainer_id(client.id, scope.user.id),
        else: scope.user.id

    params
    |> Map.put("client_id", client.id)
    |> Map.put("trainer_id", trainer_id)
  end

  defp calculate_weight_change(entries) do
    sorted = Enum.sort_by(entries, & &1.entry_date, {:asc, Date})

    case sorted do
      [] ->
        nil

      [first | _] = all ->
        last = List.last(all)
        if first.weight && last.weight, do: Decimal.sub(last.weight, first.weight), else: nil
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
          do: Decimal.sub(last.body_fat_percentage, first.body_fat_percentage),
          else: nil
    end
  end

  defp group_by_month(entries) do
    entries
    |> Enum.group_by(fn entry -> Calendar.strftime(entry.entry_date, "%Y-%m") end)
    |> Map.new(fn {key, values} -> {key, length(values)} end)
  end
end
