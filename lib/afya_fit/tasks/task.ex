defmodule AfyaFit.Tasks.Task do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tasks" do
    belongs_to :organization, AfyaFit.Organizations.Organization
    belongs_to :trainer, AfyaFit.Accounts.User
    belongs_to :client, AfyaFit.Accounts.User

    field :title, :string
    field :description, :string
    field :task_type, :string
    field :priority, :string, default: "medium"
    field :due_date, :utc_datetime
    field :is_recurring, :boolean, default: false
    field :status, :string, default: "pending"
    field :completed_at, :utc_datetime

    has_one :task_recurrence, AfyaFit.Tasks.TaskRecurrence
    has_many :task_completions, AfyaFit.Tasks.TaskCompletion

    timestamps(type: :utc_datetime)
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [
      :organization_id,
      :trainer_id,
      :client_id,
      :title,
      :description,
      :task_type,
      :priority,
      :due_date,
      :is_recurring,
      :status,
      :completed_at
    ])
    |> validate_required([:organization_id, :trainer_id, :client_id, :title, :task_type, :status])
    |> validate_inclusion(:task_type, ["workout", "nutrition", "checkin", "custom"])
    |> validate_inclusion(:priority, ["low", "medium", "high"])
    |> validate_inclusion(:status, ["pending", "in_progress", "completed", "cancelled"])
  end
end
