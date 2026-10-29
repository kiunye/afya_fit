defmodule AfyaFitWeb.API.AuthControllerTest do
  use AfyaFitWeb.ConnCase, async: true

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Accounts.User
  alias AfyaFit.Repo

  defp register(conn, attrs) do
    base = %{
      "email" => "new#{System.unique_integer([:positive])}@example.com",
      "password" => "a-long-enough-password",
      "first_name" => "New",
      "last_name" => "User"
    }

    post(conn, ~p"/api/v1/auth/register", %{"user" => Map.merge(base, attrs)})
  end

  test "trainers register with a new organization", %{conn: conn} do
    n = System.unique_integer([:positive])

    conn =
      register(conn, %{
        "role" => "trainer",
        "organization_name" => "Gym #{n}",
        "organization_subdomain" => "gym-#{n}"
      })

    assert %{"token" => _} = json_response(conn, 201)
  end

  for role <- ["admin", "org_admin", "superuser"] do
    test "self-registration as #{role} is rejected", %{conn: conn} do
      org = organization()

      conn = register(conn, %{"role" => unquote(role), "organization_id" => org.id})

      assert %{"errors" => %{"role" => _}} = json_response(conn, 422)
      assert Repo.aggregate(User, :count) == 0
    end
  end
end
