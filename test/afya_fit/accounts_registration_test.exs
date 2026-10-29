defmodule AfyaFit.AccountsRegistrationTest do
  use AfyaFit.DataCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Accounts
  alias AfyaFit.Accounts.User
  alias AfyaFit.Organizations.Organization
  alias AfyaFit.Repo

  defp params(extra) do
    n = System.unique_integer([:positive])

    Map.merge(
      %{
        "email" => "person#{n}@example.com",
        "password" => "a-long-enough-password",
        "first_name" => "Wanjiru",
        "last_name" => "Njoroge"
      },
      extra
    )
  end

  describe "register_with_organization/1" do
    test "a trainer starts their own free organization" do
      n = System.unique_integer([:positive])

      assert {:ok, user} =
               Accounts.register_with_organization(
                 params(%{
                   "role" => "trainer",
                   "organization_name" => "Gym #{n}",
                   "organization_subdomain" => "gym-#{n}"
                 })
               )

      organization = Repo.get!(Organization, user.organization_id)
      assert organization.plan_type == "free"
      assert organization.status == "active"
      assert organization.name == "Gym #{n}"
    end

    test "the person who starts an organization owns it as its org_admin" do
      n = System.unique_integer([:positive])

      assert {:ok, user} =
               Accounts.register_with_organization(
                 params(%{
                   "role" => "trainer",
                   "organization_name" => "Gym #{n}",
                   "organization_subdomain" => "gym-#{n}"
                 })
               )

      assert Repo.get!(User, user.id).role == "org_admin"
    end

    test "an invalid organization creates nothing and reports the organization's errors" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Accounts.register_with_organization(
                 params(%{
                   "role" => "trainer",
                   "organization_name" => "",
                   "organization_subdomain" => "x"
                 })
               )

      assert %{name: _} = errors_on(changeset)
      assert Repo.aggregate(User, :count) == 0
    end

    test "a client joins an existing organization by subdomain" do
      org = organization()

      assert {:ok, user} =
               Accounts.register_with_organization(
                 params(%{"role" => "client", "organization_subdomain" => org.subdomain})
               )

      assert user.organization_id == org.id
      assert user.role == "client"
    end

    test "a client cannot choose an organization by id" do
      org = organization()
      other = organization()

      assert {:ok, user} =
               Accounts.register_with_organization(
                 params(%{
                   "role" => "client",
                   "organization_subdomain" => org.subdomain,
                   "organization_id" => other.id
                 })
               )

      assert user.organization_id == org.id
    end

    test "an unknown subdomain is an error on the subdomain" do
      assert {:error, changeset} =
               Accounts.register_with_organization(
                 params(%{"role" => "client", "organization_subdomain" => "nowhere"})
               )

      assert %{organization_subdomain: ["not found"]} = errors_on(changeset)
    end

    test "privileged and unknown roles are rejected" do
      org = organization()

      for role <- ["admin", "org_admin", "superuser"] do
        assert {:error, changeset} =
                 Accounts.register_with_organization(
                   params(%{"role" => role, "organization_id" => org.id})
                 )

        assert %{role: _} = errors_on(changeset)
      end

      assert Repo.aggregate(User, :count) == 0
    end
  end
end
