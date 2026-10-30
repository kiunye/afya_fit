defmodule AfyaFit.Clients do
  @moduledoc """
  The Clients context for managing trainer-client relationships.
  """
  import Ecto.Query, warn: false
  alias AfyaFit.Accounts.{TrainerClient, User}
  alias AfyaFit.Accounts
  alias AfyaFit.Authorization
  alias AfyaFit.Authorization.Scope
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
  Lists all clients in the trainer's organization.
  """
  def list_organization_clients(organization_id, filters \\ %{}) do
    query =
      User
      |> where([u], u.organization_id == ^organization_id and u.role == "client")

    query =
      case Map.get(filters, :status) do
        nil ->
          where(query, [u], u.id not in subquery(TrainerClient.archived_client_ids()))

        "archived" ->
          where(query, [u], u.id in subquery(TrainerClient.archived_client_ids()))

        status when status in ["active", "paused"] ->
          query
          |> join(:inner, [u], tc in TrainerClient, on: tc.client_id == u.id)
          |> where([u, tc], tc.status == ^status)
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
  Loads the client with `id` if the scope may perform `action` on them.

  Returns `{:ok, client}`, `{:error, :not_found}` (no such client, a user who
  is not a client, or a malformed id) or the authorization error. The one place
  every API controller and LiveView uses to reach a client.
  """
  def fetch_for(%Scope{} = scope, action, id) do
    case Accounts.get_user(id) do
      %User{role: "client"} = client ->
        with :ok <- Authorization.authorize(scope, action, client), do: {:ok, client}

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Updates a client's profile details. Role, organization and credentials cannot be changed here.
  """
  def update_client(%User{} = client, attrs) do
    client
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists the clients the scope's user may see: linked clients for trainers (limited
  by `filters.status` when given) and every client in the organization for
  organization admins and platform admins.
  """
  def list_clients_for(%Scope{user: user} = scope, filters \\ %{}) do
    case Scope.role(scope) do
      :trainer ->
        links = list_trainer_clients(user.id, filters)

        links =
          if Map.has_key?(filters, :status),
            do: links,
            else: Enum.reject(links, &(&1.status == "archived"))

        Enum.map(links, & &1.client)

      role when role in [:org_admin, :admin] ->
        list_organization_clients(user.organization_id, filters)

      _ ->
        []
    end
  end

  @doc """
  Archives the trainer-client links of `client` that the scope's user may end:
  their own link for trainers, every active link for organization admins.
  """
  def archive_client_links(%User{id: client_id}, %Scope{user: user} = scope) do
    query = where(TrainerClient, [tc], tc.client_id == ^client_id and tc.status != "archived")

    query =
      if Scope.role(scope) == :trainer,
        do: where(query, [tc], tc.trainer_id == ^user.id),
        else: query

    Repo.transaction(fn ->
      for link <- Repo.all(query) do
        {:ok, archived} = archive_trainer_client(link)
        archived
      end
    end)
  end

  @doc """
  Takes an archived client back: a trainer restores their own link, an
  organization admin the most recently archived one. Restoring adds a client
  back to the plan, so the client limit and read-only billing apply.
  """
  def restore_client(%Scope{} = scope, client_id) do
    with {:ok, client_id} <- Ecto.UUID.cast(client_id),
         :ok <- Authorization.authorize(scope, :create, :client),
         %TrainerClient{} = link <- archived_link(scope, client_id) do
      update_trainer_client(link, %{status: "active", ended_at: nil})
    else
      nil -> {:error, :not_found}
      :error -> {:error, :not_found}
      error -> error
    end
  end

  defp archived_link(%Scope{user: user} = scope, client_id) do
    query =
      from tc in TrainerClient,
        join: c in assoc(tc, :client),
        where:
          tc.client_id == ^client_id and tc.status == "archived" and
            c.organization_id == ^user.organization_id,
        order_by: [desc: tc.ended_at],
        limit: 1

    query =
      if Scope.role(scope) == :trainer,
        do: where(query, [tc], tc.trainer_id == ^user.id),
        else: query

    Repo.one(query)
  end

  @doc """
  The id of the trainer currently coaching `client_id`, or `default` when the
  client has no active link.
  """
  def primary_trainer_id(client_id, default) do
    case Repo.get_by(TrainerClient, client_id: client_id, status: "active") do
      nil -> default
      %TrainerClient{trainer_id: trainer_id} -> trainer_id
    end
  end

  @doc """
  Gets nutrition plans assigned to a client.
  """
  def get_client_nutrition_plans(client_id) do
    alias AfyaFit.Nutrition.NutritionPlan

    NutritionPlan
    |> where([np], np.client_id == ^client_id)
    |> where([np], is_nil(np.deleted_at))
    |> Repo.all()
  end
end
