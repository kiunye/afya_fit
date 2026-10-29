defmodule AfyaFit.AuthorizationFixtures do
  @moduledoc false

  alias AfyaFit.Accounts.User
  alias AfyaFit.Authorization.Scope

  @org_a "org-a"
  @org_b "org-b"

  def org_a, do: @org_a
  def org_b, do: @org_b

  def user(role, attrs \\ %{}) do
    struct!(
      User,
      Map.merge(%{id: "#{role}-1", role: Atom.to_string(role), organization_id: @org_a}, attrs)
    )
  end

  def scope(role, opts \\ []) do
    {user_attrs, opts} = Keyword.pop(opts, :user, %{})

    opts =
      Keyword.merge(
        [tier: "pro", organization_status: "active", subscription_status: "active"],
        opts
      )

    Scope.new(user(role, user_attrs), opts)
  end
end
