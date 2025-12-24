defmodule AfyaFit.Clients do
  @moduledoc """
  The Clients context for managing trainer-client relationships.
  """
  import Ecto.Query, warn: false
  alias AfyaFit.Accounts.{TrainerClient, User}
  alias AfyaFit.Repo

  @doc """
  Lists all clients for a given trainer.
  """
  def list_trainer_clients(trainer_id, filters \\ %{}) do
    query =
      TrainerClient
      |> where([tc], tc.trainer_id == ^trainer_id)
      |> preload([:client, :trainer])

    query =
      case Map.get(filters, :status) do
        nil -> query
        status -> where(query, [tc], tc.status == ^status)
      end

    Repo.all(query)
  end

  @doc """
  Gets a single trainer-client relationship.
  """
  def get_trainer_client!(id) do
    TrainerClient
    |> Repo.get!(id)
    |> Repo.preload([:client, :trainer])
  end

  @doc """
  Gets a trainer-client relationship by trainer and client IDs.
  """
  def get_trainer_client_by_ids(trainer_id, client_id) do
    Repo.get_by(TrainerClient, trainer_id: trainer_id, client_id: client_id)
    |> Repo.preload([:client, :trainer])
  end

  @doc """
  Creates a trainer-client relationship.
  """
  def create_trainer_client(attrs \\ %{}) do
    %TrainerClient{}
    |> TrainerClient.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a trainer-client relationship.
  """
  def update_trainer_client(%TrainerClient{} = trainer_client, attrs) do
    trainer_client
    |> TrainerClient.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Archives a trainer-client relationship (soft delete).
  """
  def archive_trainer_client(%TrainerClient{} = trainer_client) do
    update_trainer_client(trainer_client, %{
      status: "archived",
      ended_at: DateTime.utc_now()
    })
  end

  @doc """
  Gets a client user by ID, ensuring they belong to the trainer's organization.
  """
  def get_client!(trainer, client_id) do
    # Verify client belongs to same organization
    client = Repo.get!(User, client_id)

    if client.organization_id == trainer.organization_id && client.role == "client" do
      # Verify trainer-client relationship exists
      case get_trainer_client_by_ids(trainer.id, client_id) do
        nil ->
          raise Ecto.NoResultsError, queryable: TrainerClient

        _trainer_client ->
          client
      end
    else
      raise Ecto.NoResultsError, queryable: User
    end
  end

  @doc """
  Lists all clients in the trainer's organization.
  """
  def list_organization_clients(organization_id, filters \\ %{}) do
    query =
      User
      |> where([u], u.organization_id == ^organization_id and u.role == "client")

    query =
      case Map.get(filters, :status) do
        nil ->
          query

        "active" ->
          # Only clients with active trainer relationships
          query
          |> join(:inner, [u], tc in TrainerClient, on: tc.client_id == u.id)
          |> where([u, tc], tc.status == "active")
          |> distinct([u], true)

        _ ->
          query
      end

    Repo.all(query)
  end

  @doc """
  Creates a client user and establishes trainer-client relationship.
  """
  @dialyzer {:nowarn_function, create_client: 2}
  def create_client(trainer, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:client, fn _changes ->
      User.registration_changeset(
        %User{},
        Map.merge(attrs, %{
          "organization_id" => trainer.organization_id,
          "role" => "client"
        })
      )
    end)
    |> Ecto.Multi.insert(:trainer_client, fn %{client: client} ->
      TrainerClient.changeset(
        %TrainerClient{},
        %{
          trainer_id: trainer.id,
          client_id: client.id,
          status: "active",
          started_at: DateTime.utc_now()
        }
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{client: client}} -> {:ok, client}
      {:error, :client, changeset, _} -> {:error, changeset}
      {:error, :trainer_client, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Updates a client user.
  """
  def update_client(%User{} = client, attrs) do
    client
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Checks if a trainer has access to a client.
  """
  def trainer_has_client?(trainer_id, client_id) do
    case get_trainer_client_by_ids(trainer_id, client_id) do
      nil -> false
      %TrainerClient{status: status} -> status in ["active", "paused"]
    end
  end
end
