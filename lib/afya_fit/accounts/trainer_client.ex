defmodule AfyaFit.Accounts.TrainerClient do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  @moduledoc false

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "trainer_clients" do
    belongs_to :trainer, AfyaFit.Accounts.User
    belongs_to :client, AfyaFit.Accounts.User
    field :status, :string, default: "active"
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  @doc "Ids of clients with a link that is still running (active or paused)."
  def live_client_ids,
    do: from(tc in __MODULE__, where: tc.status in ["active", "paused"], select: tc.client_id)

  @doc """
  Ids of clients whose coaching has ended: they have links, and every one is
  archived. A client who was never linked is not archived.
  """
  def archived_client_ids do
    from(tc in __MODULE__,
      where: tc.status == "archived" and tc.client_id not in subquery(live_client_ids()),
      select: tc.client_id
    )
  end

  def changeset(trainer_client, attrs) do
    trainer_client
    |> cast(attrs, [:trainer_id, :client_id, :status, :started_at, :ended_at, :notes])
    |> validate_required([:trainer_id, :client_id, :status, :started_at])
    |> validate_inclusion(:status, ["active", "paused", "archived"])
    |> unique_constraint([:trainer_id, :client_id])
    |> check_constraint(:trainer_id,
      name: :trainer_cannot_be_client,
      message: "trainer and client cannot be the same"
    )
  end
end
