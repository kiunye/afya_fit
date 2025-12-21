defmodule AfyaFitWeb.API.JSON.ProgressEntryJSON do
  @moduledoc """
  JSON serialization for ProgressEntry resources.
  """

  def index(%{progress_entries: progress_entries}) do
    %{data: for(entry <- progress_entries, do: data(entry))}
  end

  def show(%{progress_entry: progress_entry}) do
    %{data: data(progress_entry)}
  end

  defp data(%{id: id} = entry) do
    %{
      id: id,
      client_id: entry.client_id,
      trainer_id: entry.trainer_id,
      entry_date: entry.entry_date,
      weight: entry.weight,
      body_fat_percentage: entry.body_fat_percentage,
      notes: entry.notes,
      inserted_at: entry.inserted_at,
      updated_at: entry.updated_at
    }
  end
end
