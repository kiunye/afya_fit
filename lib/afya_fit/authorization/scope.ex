defmodule AfyaFit.Authorization.Scope do
  @moduledoc """
  Everything an authorization decision needs to know about the requester.

  A scope is built once per request (or job) with `load/1` and then passed to
  `AfyaFit.Authorization`. Policies only read from it, so decisions stay pure
  and cheap to test with `new/2`.
  """

  import Ecto.Query

  alias AfyaFit.Accounts.{TrainerClient, User}
  alias AfyaFit.Billing.Subscription
  alias AfyaFit.Organizations.Organization
  alias AfyaFit.Repo

  @roles %{
    "admin" => :admin,
    "org_admin" => :org_admin,
    "trainer" => :trainer,
    "client" => :client
  }

  defstruct user: nil,
            organization: nil,
            owner_name: nil,
            tier: "free",
            organization_status: "active",
            subscription_status: nil,
            period_end: nil,
            cancel_at_period_end: false,
            client_ids: MapSet.new(),
            client_count: 0

  @type role :: :admin | :org_admin | :trainer | :client | :none

  @type t :: %__MODULE__{
          user: User.t(),
          organization: struct() | nil,
          owner_name: String.t() | nil,
          tier: String.t(),
          organization_status: String.t() | nil,
          subscription_status: String.t() | nil,
          period_end: DateTime.t() | nil,
          cancel_at_period_end: boolean(),
          client_ids: MapSet.t(binary()),
          client_count: non_neg_integer()
        }

  @doc """
  Builds a scope without touching the database.

  Options: `:organization`, `:tier`, `:organization_status`, `:subscription_status`,
  `:period_end`, `:client_ids` (a list) and `:client_count`.
  """
  @spec new(User.t(), keyword()) :: t()
  def new(%User{} = user, opts \\ []) do
    opts = Keyword.update(opts, :client_ids, MapSet.new(), &MapSet.new/1)
    struct!(__MODULE__, Keyword.put(opts, :user, user))
  end

  @doc """
  Builds a scope for `user`, loading the organization, its subscription and the
  clients the user is allowed to reach.
  """
  @spec load(User.t()) :: t()
  def load(%User{} = user) do
    organization = Repo.get(Organization, user.organization_id)

    subscription =
      Repo.one(
        from s in Subscription,
          where: s.organization_id == ^user.organization_id,
          order_by: [desc: s.inserted_at],
          limit: 1
      )

    new(user,
      organization: organization,
      owner_name: owner_name(user.organization_id),
      tier: organization && organization.plan_type,
      organization_status: organization && organization.status,
      subscription_status: subscription && subscription.status,
      period_end: subscription && subscription.current_period_end,
      cancel_at_period_end: (subscription && subscription.cancel_at_period_end) || false,
      client_ids: linked_client_ids(user),
      client_count: count_clients(user.organization_id)
    )
  end

  @spec role(t()) :: role()
  def role(%__MODULE__{user: %User{role: role}}), do: Map.get(@roles, role, :none)

  @doc "True when the requester is the user with `id`."
  @spec self?(t(), binary() | nil) :: boolean()
  def self?(%__MODULE__{user: user}, id), do: not is_nil(id) and user.id == id

  @doc """
  True when the requester coaches the client with `client_id`: organization
  admins reach every client in their organization, trainers only linked ones.
  """
  @spec manages_client?(t(), binary() | nil) :: boolean()
  def manages_client?(%__MODULE__{} = scope, client_id) do
    case role(scope) do
      :org_admin -> not is_nil(client_id)
      :trainer -> MapSet.member?(scope.client_ids, client_id)
      _ -> false
    end
  end

  # The person to ask about billing: the organization admin, else the longest-serving trainer.
  defp owner_name(organization_id) do
    from(u in User,
      where:
        u.organization_id == ^organization_id and u.role in ["org_admin", "trainer"] and
          is_nil(u.deleted_at),
      order_by: [asc: u.role, asc: u.inserted_at],
      limit: 1,
      select: {u.first_name, u.last_name}
    )
    |> Repo.one()
    |> case do
      {first, last} -> String.trim("#{first} #{last}")
      nil -> nil
    end
  end

  defp linked_client_ids(%User{role: "trainer", id: trainer_id}) do
    from(tc in TrainerClient,
      where: tc.trainer_id == ^trainer_id and tc.status in ["active", "paused"],
      select: tc.client_id
    )
    |> Repo.all()
  end

  defp linked_client_ids(_user), do: []

  defp count_clients(organization_id) do
    Repo.aggregate(
      from(u in User,
        where:
          u.organization_id == ^organization_id and u.role == "client" and is_nil(u.deleted_at)
      ),
      :count
    )
  end
end
