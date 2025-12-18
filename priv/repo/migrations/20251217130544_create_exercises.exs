defmodule AfyaFit.Repo.Migrations.CreateExercises do
  use Ecto.Migration

  def change do
    create table(:exercises, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :category, :string, null: false
      add :muscle_groups, {:array, :string}
      add :equipment_needed, {:array, :string}
      add :description, :text
      add :default_video_url, :string

      timestamps()
    end

    create unique_index(:exercises, [:name])
    create index(:exercises, [:category])
    create index(:exercises, [:muscle_groups], using: "GIN")
  end
end
