defmodule AfyaFit.Repo.Migrations.CreateProgressEntries do
  use Ecto.Migration

  def change do
    # Progress Entries
    create table(:progress_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :client_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :trainer_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :entry_date, :date, null: false
      add :weight, :decimal, precision: 5, scale: 2
      add :body_fat_percentage, :decimal, precision: 5, scale: 2
      add :notes, :text

      timestamps()
    end

    create index(:progress_entries, [:client_id])
    create index(:progress_entries, [:trainer_id])
    create unique_index(:progress_entries, [:client_id, :entry_date])

    # Progress Measurements
    create table(:progress_measurements, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :progress_entry_id,
          references(:progress_entries, on_delete: :delete_all, type: :binary_id),
          null: false

      add :measurement_type, :string, null: false
      add :value, :decimal, precision: 6, scale: 2, null: false
      add :unit, :string, default: "cm"

      timestamps(updated_at: false)
    end

    create index(:progress_measurements, [:progress_entry_id])
    create index(:progress_measurements, [:measurement_type])

    # Progress Photos
    create table(:progress_photos, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :progress_entry_id,
          references(:progress_entries, on_delete: :delete_all, type: :binary_id),
          null: false

      add :photo_type, :string, null: false
      add :url, :string, null: false
      add :thumbnail_url, :string
      add :order_index, :integer, default: 0

      timestamps(updated_at: false)
    end

    create index(:progress_photos, [:progress_entry_id])
    create index(:progress_photos, [:photo_type])
  end
end
