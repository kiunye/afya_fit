defmodule AfyaFit.Tracking do
  @moduledoc """
  The Tracking context.
  """
  import Ecto.Query, warn: false
  alias AfyaFit.Repo
  alias AfyaFit.Tracking.{ProgressEntry, ProgressMeasurement, ProgressPhoto}

  def list_progress_entries(client_id) do
    ProgressEntry
    |> where([p], p.client_id == ^client_id)
    |> Repo.all()
  end

  def get_progress_entry!(id), do: Repo.get!(ProgressEntry, id)

  def create_progress_entry(attrs \\ %{}) do
    %ProgressEntry{}
    |> ProgressEntry.changeset(attrs)
    |> Repo.insert()
  end

  def update_progress_entry(%ProgressEntry{} = progress_entry, attrs) do
    progress_entry
    |> ProgressEntry.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_progress_entry(%ProgressEntry{} = progress_entry) do
    Repo.delete(progress_entry)
  end

  def change_progress_entry(%ProgressEntry{} = progress_entry, attrs \\ %{}) do
    ProgressEntry.changeset(progress_entry, attrs)
  end

  # Measurements and Photos
  def create_progress_measurement(attrs \\ %{}) do
    %ProgressMeasurement{}
    |> ProgressMeasurement.changeset(attrs)
    |> Repo.insert()
  end

  def create_progress_photo(attrs \\ %{}) do
    %ProgressPhoto{}
    |> ProgressPhoto.changeset(attrs)
    |> Repo.insert()
  end
end
