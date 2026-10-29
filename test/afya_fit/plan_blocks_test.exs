defmodule AfyaFit.PlanBlocksTest do
  use AfyaFit.DataCase, async: true
  use Oban.Testing, repo: AfyaFit.Repo

  import AfyaFitWeb.APIFixtures
  import ExUnit.CaptureLog
  import Swoosh.TestAssertions

  alias AfyaFit.Authorization.Scope
  alias AfyaFit.PlanBlocks
  alias AfyaFit.Workers.PlanBlockedWorker

  setup do
    org = organization(%{name: "Njoroge Strength", plan_type: "free"})
    trainer = user(org, :trainer, %{first_name: "Brian", last_name: "Kariuki"})
    %{org: org, trainer: trainer, scope: Scope.load(trainer)}
  end

  @upgrade {:error, {:upgrade_required, %{feature: :nutrition_plans, required_tier: "pro"}}}

  test "a plan limit is logged and queues one support email", %{scope: scope, org: org} do
    log = capture_log(fn -> assert :ok = PlanBlocks.record(scope, @upgrade) end)

    assert log =~ "plan_blocked kind=upgrade_required feature=nutrition_plans tier=free"
    assert log =~ "organization_id=#{org.id}"

    assert_enqueued(
      worker: PlanBlockedWorker,
      args: %{kind: "upgrade_required", feature: "nutrition_plans", organization_id: org.id}
    )
  end

  test "repeated blocks for the same organisation and feature queue only one email", %{
    scope: scope
  } do
    for _ <- 1..3, do: PlanBlocks.record(scope, @upgrade)

    assert [_one] = all_enqueued(worker: PlanBlockedWorker)
  end

  test "a different feature, or a different organisation, queues its own", %{scope: scope} do
    PlanBlocks.record(scope, @upgrade)

    PlanBlocks.record(
      scope,
      {:error, {:upgrade_required, %{feature: :clients, required_tier: "pro"}}}
    )

    other = organization(%{plan_type: "free"})
    PlanBlocks.record(Scope.load(user(other, :trainer)), @upgrade)

    assert length(all_enqueued(worker: PlanBlockedWorker)) == 3
  end

  test "a read-only account is recorded too", %{scope: scope} do
    PlanBlocks.record(scope, {:error, {:subscription_inactive, "cancelled"}})

    assert_enqueued(
      worker: PlanBlockedWorker,
      args: %{kind: "subscription_inactive", status: "cancelled"}
    )
  end

  test "other errors are ignored", %{scope: scope} do
    for error <- [{:error, :forbidden}, {:error, :not_found}, :ok, nil] do
      assert :ok = PlanBlocks.record(scope, error)
    end

    refute_enqueued(worker: PlanBlockedWorker)
  end

  test "no scope means nothing to record" do
    assert :ok = PlanBlocks.record(nil, @upgrade)
    refute_enqueued(worker: PlanBlockedWorker)
  end

  describe "the email" do
    test "tells support who wanted what, on which plan", %{scope: scope} do
      PlanBlocks.record(scope, @upgrade)

      assert :ok =
               perform_job(PlanBlockedWorker, hd(all_enqueued(worker: PlanBlockedWorker)).args)

      assert_email_sent(fn email ->
        assert email.to == [{"", "kiunyearaya@gmail.com"}]
        assert email.subject == "Wants nutrition plans: Njoroge Strength (free)"
        assert email.text_body =~ "Brian Kariuki (trainer, #{scope.user.email})"
        assert email.text_body =~ "needs pro"
        assert email.text_body =~ "next 24 hours"
      end)
    end

    test "a read-only account has its own wording", %{scope: scope} do
      PlanBlocks.record(scope, {:error, {:subscription_inactive, "cancelled"}})

      perform_job(PlanBlockedWorker, hd(all_enqueued(worker: PlanBlockedWorker)).args)

      assert_email_sent(fn email ->
        assert email.subject == "Read-only account: Njoroge Strength"
        assert email.text_body =~ "read-only (cancelled)"
      end)
    end

    test "goes to the configured support address", %{scope: scope} do
      Application.put_env(:afya_fit, :support_email, "support@example.test")
      on_exit(fn -> Application.put_env(:afya_fit, :support_email, "kiunyearaya@gmail.com") end)

      PlanBlocks.record(scope, @upgrade)
      perform_job(PlanBlockedWorker, hd(all_enqueued(worker: PlanBlockedWorker)).args)

      assert_email_sent(fn email -> assert email.to == [{"", "support@example.test"}] end)
    end

    test "sends nothing when no support address is configured", %{scope: scope} do
      Application.delete_env(:afya_fit, :support_email)
      on_exit(fn -> Application.put_env(:afya_fit, :support_email, "kiunyearaya@gmail.com") end)

      PlanBlocks.record(scope, @upgrade)

      assert :ok =
               perform_job(PlanBlockedWorker, hd(all_enqueued(worker: PlanBlockedWorker)).args)

      assert_no_email_sent()
    end
  end
end
