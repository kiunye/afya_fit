defmodule AfyaFit.RLSTest do
  # Switches enforcement on for the node, so it cannot run alongside other tests.
  use AfyaFit.DataCase, async: false

  import AfyaFitWeb.APIFixtures

  alias AfyaFit.Accounts.{TrainerClient, User}
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Repo
  alias AfyaFit.RLS

  setup do
    previous = Application.get_env(:afya_fit, AfyaFit.RLS)
    Application.put_env(:afya_fit, AfyaFit.RLS, Keyword.put(previous, :enforce, true))
    on_exit(fn -> Application.put_env(:afya_fit, AfyaFit.RLS, previous) end)

    AfyaFit.DataCase.enforce_rls_if_configured()

    a = organization()
    b = organization()
    %{a: a, b: b, trainer_a: user(a, "trainer"), trainer_b: user(b, "trainer")}
  end

  defp ids(users), do: users |> Enum.map(& &1.id) |> Enum.sort()

  test "a scope sees its own organization's rows and no one else's", ctx do
    %{trainer_a: ta, trainer_b: tb} = ctx

    assert ids(RLS.with_scope(Scope.new(ta), fn -> Repo.all(User) end)) == [ta.id]
    assert ids(RLS.with_scope(Scope.new(tb), fn -> Repo.all(User) end)) == [tb.id]
  end

  test "rows reached through a parent follow the parent's organization", ctx do
    %{a: a, b: b, trainer_a: ta, trainer_b: tb} = ctx
    link(ta, user(a, "client"))
    link(tb, user(b, "client"))

    assert [%{trainer_id: trainer_id}] =
             RLS.with_scope(Scope.new(ta), fn -> Repo.all(TrainerClient) end)

    assert trainer_id == ta.id
  end

  test "code with no context sees nothing", %{trainer_a: ta} do
    RLS.put_ambient_context({nil, nil})

    assert Repo.all(User) == []
    assert RLS.with_scope(Scope.new(ta), fn -> Repo.all(User) end) |> ids() == [ta.id]
  end

  test "the system and platform admins see every organization", ctx do
    %{trainer_a: ta, trainer_b: tb, a: a} = ctx
    admin = user(a, "admin")

    assert ids(RLS.unscoped(fn -> Repo.all(User) end)) == ids([ta, tb, admin])

    assert ids(RLS.with_scope(Scope.new(admin), fn -> Repo.all(User) end)) ==
             ids([ta, tb, admin])
  end

  test "a scope cannot write into another organization", ctx do
    %{trainer_a: ta, trainer_b: tb, b: b} = ctx

    assert_raise Postgrex.Error, ~r/row-level security/, fn ->
      RLS.with_scope(Scope.new(ta), fn ->
        Repo.insert!(%User{
          email: "intruder@example.com",
          role: "trainer",
          first_name: "In",
          last_name: "Truder",
          organization_id: b.id
        })
      end)
    end

    {updated, _} =
      RLS.with_scope(Scope.new(ta), fn ->
        import Ecto.Query
        Repo.update_all(from(u in User, where: u.id == ^tb.id), set: [first_name: "Hacked"])
      end)

    assert updated == 0
  end

  test "the context is put back afterwards", %{trainer_a: ta, trainer_b: tb} do
    RLS.with_scope(Scope.new(ta), fn -> :ok end)

    assert ids(Repo.all(User)) |> Enum.member?(tb.id)
  end

  test "a failed transaction inside a scope does not break the rest of it", %{trainer_a: ta} do
    result =
      RLS.with_scope(Scope.new(ta), fn ->
        assert {:error, :nope} = Repo.transaction(fn -> Repo.rollback(:nope) end)
        Repo.all(User)
      end)

    assert ids(result) == [ta.id]
  end

  test "with enforcement off, scoping just calls through", %{trainer_b: tb} do
    Application.put_env(
      :afya_fit,
      AfyaFit.RLS,
      Keyword.put(Application.get_env(:afya_fit, AfyaFit.RLS), :enforce, false)
    )

    assert RLS.with_scope(Scope.new(tb), fn -> :ran end) == :ran
    assert RLS.unscoped(fn -> :ran end) == :ran
  end
end
