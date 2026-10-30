defmodule AfyaFit.Platform do
  @moduledoc """
  What platform admins do across organizations: look at one, suspend or
  reactivate it, grant it a plan, review subscriptions and find people.

  Everything here needs the `:manage` or `:access` permission on `:admin_panel`,
  and every change is written to the target organization's activity log, so its
  owner can see what was done. Platform admins act on organization-level state
  only; they do not edit a tenant's workouts, plans or clients.
  """

  import Ecto.Query

  alias AfyaFit.Accounts.{TrainerClient, User}
  alias AfyaFit.{Authorization, Billing, Organizations, Repo, Shared}
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Billing.Subscription
  alias AfyaFit.Organizations.Organization
  alias AfyaFit.Shared.ActivityLog

  @plans ~w(free pro enterprise)
  @grant_days [30, 90, 365]
  @subscription_filters ~w(active past_due cancelling cancelled expired)

  def plans, do: @plans
  def grant_days, do: @grant_days
  def subscription_filters, do: @subscription_filters

  @doc "The organization with `id`, or `{:error, :not_found}`."
  def get_organization(id) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %Organization{deleted_at: nil} = organization <- Repo.get(Organization, id) do
      {:ok, organization}
    else
      _ -> {:error, :not_found}
    end
  end

  @doc "Everything the organization page shows."
  def overview(%Organization{} = organization) do
    subscription = Billing.get_subscription_by_organization(organization.id)

    %{
      organization: organization,
      tier: Scope.effective_tier(organization, subscription),
      subscription: subscription,
      team: team(organization),
      client_count: client_count(organization),
      invoices: if(subscription, do: Billing.list_invoices(subscription.id), else: []),
      activity: activity(organization)
    }
  end

  defp team(organization) do
    Repo.all(
      from u in User,
        where:
          u.organization_id == ^organization.id and u.role in ["org_admin", "trainer"] and
            is_nil(u.deleted_at),
        order_by: [asc: u.role, asc: u.inserted_at]
    )
  end

  # The same count the plan limit uses: archived clients do not take a place.
  defp client_count(organization) do
    Repo.aggregate(
      from(u in User,
        where:
          u.organization_id == ^organization.id and u.role == "client" and
            is_nil(u.deleted_at) and u.id not in subquery(TrainerClient.archived_client_ids())
      ),
      :count
    )
  end

  defp activity(organization) do
    Repo.all(
      from l in ActivityLog,
        where: l.organization_id == ^organization.id,
        order_by: [desc: l.inserted_at],
        limit: 10
    )
  end

  @doc """
  Suspends or reactivates an organization. A suspended organization is
  read-only, like one that has not paid; nobody is locked out of their data.
  """
  def set_status(%Scope{} = scope, %Organization{} = organization, status)
      when status in ["active", "suspended"] do
    with :ok <- Authorization.authorize(scope, :manage, :admin_panel),
         {:ok, updated} <- Organizations.update_organization(organization, %{status: status}) do
      log(scope, updated, "platform.#{status}", %{from: organization.status})
      {:ok, updated}
    end
  end

  @doc """
  Puts an organization on `plan` for `days` days without a payment, for a comp
  or a manual correction. Creates the subscription if there is none.
  """
  def grant_plan(%Scope{} = scope, %Organization{} = organization, plan, days)
      when plan in @plans and days in @grant_days do
    with :ok <- Authorization.authorize(scope, :manage, :admin_panel) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      attrs = %{
        organization_id: organization.id,
        plan_type: plan,
        status: "active",
        current_period_start: now,
        current_period_end: DateTime.add(now, days, :day),
        cancel_at_period_end: false,
        cancelled_at: nil
      }

      Repo.transaction(fn ->
        subscription = Repo.get_by(Subscription, organization_id: organization.id)
        changeset = Subscription.changeset(subscription || %Subscription{}, attrs)

        with {:ok, saved} <- Repo.insert_or_update(changeset),
             {:ok, _} <- Organizations.update_organization(organization, %{plan_type: plan}) do
          log(scope, organization, "platform.grant_plan", %{plan: plan, days: days})
          saved
        else
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
    end
  end

  @doc """
  Subscriptions across organizations, soonest period end first. `filter` is one
  of `subscription_filters/0`; anything else lists them all.
  """
  def list_subscriptions(filter \\ nil) do
    query =
      from s in Subscription,
        join: o in Organization,
        on: o.id == s.organization_id,
        where: is_nil(o.deleted_at),
        order_by: [asc: s.current_period_end],
        select: %{
          id: s.id,
          organization_id: o.id,
          organization: o.name,
          plan_type: s.plan_type,
          status: s.status,
          cancel_at_period_end: s.cancel_at_period_end,
          period_end: s.current_period_end
        }

    query
    |> filter_subscriptions(filter)
    |> Repo.all()
  end

  defp filter_subscriptions(query, "cancelling"),
    do: where(query, [s], s.status == "cancelled" and s.cancel_at_period_end)

  defp filter_subscriptions(query, "cancelled"),
    do: where(query, [s], s.status == "cancelled" and not s.cancel_at_period_end)

  defp filter_subscriptions(query, status) when status in @subscription_filters,
    do: where(query, [s], s.status == ^status)

  defp filter_subscriptions(query, _other), do: query

  @doc "People matching `term` by name or email, across organizations. Needs two characters."
  def search_users(term) do
    term = term |> to_string() |> String.trim()

    if String.length(term) < 2 do
      []
    else
      pattern = "%" <> escape_like(term) <> "%"

      Repo.all(
        from u in User,
          join: o in Organization,
          on: o.id == u.organization_id,
          where:
            is_nil(u.deleted_at) and
              (ilike(u.email, ^pattern) or ilike(u.first_name, ^pattern) or
                 ilike(u.last_name, ^pattern)),
          order_by: [asc: u.email],
          limit: 50,
          select: %{
            id: u.id,
            email: u.email,
            name: fragment("? || ' ' || ?", u.first_name, u.last_name),
            role: u.role,
            organization_id: o.id,
            organization: o.name
          }
      )
    end
  end

  defp escape_like(term), do: String.replace(term, ["\\", "%", "_"], &("\\" <> &1))

  defp log(%Scope{user: actor}, %Organization{} = organization, action, metadata) do
    Shared.create_activity_log(%{
      organization_id: organization.id,
      user_id: actor.id,
      action: action,
      resource_type: "organization",
      resource_id: organization.id,
      metadata: metadata
    })
  end
end
