defmodule AfyaFitWeb.APIFixtures do
  @moduledoc """
  Database-backed fixtures for API tests: organizations, users with any role,
  trainer-client links, subscriptions and authenticated connections.
  """

  import Plug.Conn

  alias AfyaFit.Accounts
  alias AfyaFit.Accounts.{TrainerClient, User}
  alias AfyaFit.Billing.Subscription
  alias AfyaFit.Organizations.Organization
  alias AfyaFit.Repo

  def organization(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    %Organization{}
    |> Organization.changeset(
      Map.merge(
        %{name: "Org #{n}", subdomain: "org-#{n}", plan_type: "pro", status: "active"},
        attrs
      )
    )
    |> Repo.insert!()
  end

  def user(%Organization{} = organization, role, attrs \\ %{}) do
    n = System.unique_integer([:positive])

    %User{}
    |> User.changeset(
      Map.merge(
        %{
          email: "#{role}-#{n}@example.com",
          password_hash: "not-a-real-hash",
          role: to_string(role),
          first_name: "First#{n}",
          last_name: "Last#{n}",
          organization_id: organization.id
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  def link(%User{} = trainer, %User{} = client, status \\ "active") do
    Repo.insert!(%TrainerClient{
      trainer_id: trainer.id,
      client_id: client.id,
      status: status,
      started_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  def subscription(%Organization{} = organization, attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Subscription{}
    |> Subscription.changeset(
      Map.merge(
        %{
          organization_id: organization.id,
          plan_type: "pro",
          status: "active",
          current_period_start: DateTime.add(now, -10, :day),
          current_period_end: DateTime.add(now, 20, :day)
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  @doc "Logs `user` into a browser session, for controller and LiveView tests."
  def log_in(conn, %User{} = user) do
    token = Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> put_session(:user_token, token)
  end

  @doc "Adds a bearer token for `user` to the connection."
  def authenticate(conn, %User{} = user) do
    token = Accounts.generate_user_session_token(user)

    conn
    |> put_req_header("authorization", "Bearer " <> token)
    |> put_req_header("accept", "application/json")
  end
end
