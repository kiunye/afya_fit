defmodule AfyaFit.Tasks.TaskCompletion do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "task_completions" do
    belongs_to :task, AfyaFit.Tasks.Task

    field :completed_date, :date
    field :notes, :string

    timestamps(updated_at: false, type: :utc_datetime)
  end

  def changeset(completion, attrs) do
    completion
    |> cast(attrs, [:task_id, :completed_date, :notes])
    |> validate_required([:task_id, :completed_date])
    |> unique_constraint([:task_id, :completed_date])
  end
end
