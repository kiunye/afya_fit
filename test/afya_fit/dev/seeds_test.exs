defmodule AfyaFit.Dev.SeedsTest do
  use AfyaFit.DataCase, async: true

  alias AfyaFit.Accounts
  alias AfyaFit.Accounts.{TrainerClient, User}
  alias AfyaFit.Authorization
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Billing.{Payment, Subscription}
  alias AfyaFit.Dev.Seeds
  alias AfyaFit.Organizations.Organization
  alias AfyaFit.Repo

  setup do
    %{result: Seeds.run()}
  end

  defp org(subdomain), do: Repo.get_by!(Organization, subdomain: subdomain)
  defp user(email), do: Repo.get_by!(User, email: email)
  defp scope_of(email), do: email |> user() |> Scope.load()
  defp billing_of(email), do: email |> scope_of() |> Scope.billing()

  test "everyone can sign in with the demo password", %{result: result} do
    emails =
      [
        result.admin.email
        | Enum.flat_map(result.organizations, &[&1.owner | &1.trainers ++ &1.clients])
      ]

    assert length(emails) > 25

    for email <- emails do
      assert %User{} = Accounts.get_user_by_email_and_password(email, Seeds.password()), email
    end
  end

  test "running it again changes nothing" do
    counts = fn ->
      for schema <- [Organization, User, TrainerClient, Subscription, Payment, AfyaFit.Tasks.Task],
          do: Repo.aggregate(schema, :count)
    end

    before = counts.()
    Seeds.run()

    assert counts.() == before
  end

  describe "the billing states" do
    test "a healthy Pro organisation", %{result: _} do
      assert %{state: :active, reason: nil} = billing_of("brian@peak.test")
      assert scope_of("brian@peak.test").tier == "pro"
    end

    test "Free at its client limit, with one client archived" do
      scope = scope_of("wanjiru@njoroge.test")

      assert scope.tier == "free"
      assert scope.client_count == 3

      assert {:error, {:upgrade_required, %{feature: :clients}}} =
               Authorization.authorize(scope, :create, :client)
    end

    test "inside the grace period, then read-only" do
      assert %{state: :active, reason: :grace} = billing_of("daniel@grace.test")
      assert %{state: :read_only, reason: :past_due} = billing_of("esther@lapsed.test")
    end

    test "cancelled but not over" do
      assert %{state: :active, reason: :cancelling} = billing_of("peter@leaving.test")
    end

    test "suspended" do
      assert %{state: :read_only, reason: :inactive} = billing_of("lucy@suspended.test")
    end

    test "Enterprise has no client limit" do
      assert scope_of("grace@titan.test").tier == "enterprise"
      assert :ok = Authorization.authorize(scope_of("grace@titan.test"), :create, :client)
    end
  end

  test "the platform admin is in an organisation of their own", %{result: result} do
    assert Scope.role(scope_of(result.admin.email)) == :admin
  end

  test "archived clients are read-only for themselves" do
    archived =
      Repo.all(from tc in TrainerClient, where: tc.status == "archived", select: tc.client_id)

    assert archived != []
    assert Enum.any?(archived, &Scope.load(Repo.get!(User, &1)).archived)
  end

  test "Peak has payments in every state to look at" do
    statuses = Repo.all(from p in Payment, select: p.status) |> Enum.uniq() |> Enum.sort()

    assert statuses == ["failed", "pending", "succeeded"]
  end

  test "calendar events land on the trainer's day" do
    trainer = user("amina@peak.test")
    events = Repo.all(from e in AfyaFit.Schedule.CalendarEvent, where: e.user_id == ^trainer.id)

    assert length(events) == 4
    assert Enum.all?(events, &(&1.timezone == "Africa/Nairobi"))
  end
end
