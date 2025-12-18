defmodule AfyaFit.Tasks.TaskRecurrence do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "task_recurrence" do
    belongs_to :task, AfyaFit.Tasks.Task

    field :frequency, :string
    field :interval, :integer, default: 1
    field :days_of_week, {:array, :integer}
    field :day_of_month, :integer
    field :end_date, :date
    field :max_occurrences, :integer

    timestamps(updated_at: false, type: :utc_datetime)
  end

  def changeset(recurrence, attrs) do
    recurrence
    |> cast(attrs, [
      :task_id,
      :frequency,
      :interval,
      :days_of_week,
      :day_of_month,
      :end_date,
      :max_occurrences
    ])
    |> validate_required([:task_id, :frequency])
    |> validate_inclusion(:frequency, ["daily", "weekly", "monthly"])
  end
end
