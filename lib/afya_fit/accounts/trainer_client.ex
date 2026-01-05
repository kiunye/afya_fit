defmodule AfyaFit.Accounts.TrainerClient do
  use Ecto.Schema
  import Ecto.Changeset

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
