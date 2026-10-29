defmodule AfyaFit.AccountsPromotionTest do
  use AfyaFit.DataCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Accounts
  alias AfyaFit.Accounts.User
  alias AfyaFit.Repo

  defp role_of(user), do: Repo.get!(User, user.id).role

  defp age(user, seconds) do
    at = DateTime.add(DateTime.utc_now(), -seconds, :second) |> DateTime.truncate(:second)

    Repo.update_all(from(u in User, where: u.id == ^user.id), set: [inserted_at: at])
  end

  describe "promote_first_trainers/0" do
    test "promotes the earliest trainer of an organization" do
      org = organization()
      first = user(org, "trainer")
      second = user(org, "trainer")
      age(first, 100)
      age(second, 50)

      assert Accounts.promote_first_trainers() == [first.id]

      assert role_of(first) == "org_admin"
      assert role_of(second) == "trainer"
    end

    test "leaves organizations that already have an org_admin alone" do
      org = organization()
      owner = user(org, "trainer")
      Repo.update_all(from(u in User, where: u.id == ^owner.id), set: [role: "org_admin"])
      other = user(org, "trainer")

      assert Accounts.promote_first_trainers() == []
      assert role_of(other) == "trainer"
    end

    test "handles each organization separately and skips ones without trainers" do
      a = organization()
      b = organization()
      _empty = organization()
      in_a = user(a, "trainer")
      in_b = user(b, "trainer")

      assert Enum.sort(Accounts.promote_first_trainers()) == Enum.sort([in_a.id, in_b.id])
    end

    test "does not touch clients" do
      org = organization()
      client = user(org, "client")

      assert Accounts.promote_first_trainers() == []
      assert role_of(client) == "client"
    end

    test "running it again changes nothing" do
      org = organization()
      user(org, "trainer")
      user(org, "trainer")

      assert [_] = Accounts.promote_first_trainers()
      assert Accounts.promote_first_trainers() == []
    end
  end
end
