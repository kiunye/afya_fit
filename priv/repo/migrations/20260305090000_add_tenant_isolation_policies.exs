defmodule AfyaFit.Repo.Migrations.AddTenantIsolationPolicies do
  use Ecto.Migration

  # Row-level security for every tenant table, plus the non-owner role the app
  # runs as when `AfyaFit.RLS` enforcement is on. Table owners bypass RLS, so
  # the policies only bite for that role; with enforcement off nothing changes.
  #
  # Policies read two settings the app sets per transaction (see AfyaFit.Repo):
  # `app.current_organization_id` and `app.current_user_role`. The roles `admin`
  # (platform admin) and `system` (sign-in, webhooks, jobs) see every row.

  @app_role "afya_fit_app"

  # Tables with their own organization_id column.
  @direct ~w(users workout_plans nutrition_plans tasks calendar_events subscriptions
             tags activity_logs client_subscriptions)

  # {table, column, parent}: visible when the parent row is. The parent's own
  # policy decides, so these follow the tenant boundary without a copy of it.
  @children [
    {"trainer_clients", "trainer_id", "users"},
    {"client_workouts", "client_id", "users"},
    {"progress_entries", "client_id", "users"},
    {"user_preferences", "user_id", "users"},
    {"device_tokens", "user_id", "users"},
    {"users_tokens", "user_id", "users"},
    {"workout_exercises", "workout_plan_id", "workout_plans"},
    {"workout_plan_tags", "workout_plan_id", "workout_plans"},
    {"workout_completions", "client_workout_id", "client_workouts"},
    {"nutrition_meals", "nutrition_plan_id", "nutrition_plans"},
    {"nutrition_plan_tags", "nutrition_plan_id", "nutrition_plans"},
    {"progress_measurements", "progress_entry_id", "progress_entries"},
    {"progress_photos", "progress_entry_id", "progress_entries"},
    {"task_recurrence", "task_id", "tasks"},
    {"task_completions", "task_id", "tasks"},
    {"calendar_event_attendees", "event_id", "calendar_events"},
    {"invoices", "subscription_id", "subscriptions"}
  ]

  # Policies from the first RLS migration, replaced by `tenant_isolation`.
  @old_policies ~w(users workout_plans nutrition_plans tasks calendar_events activity_logs)

  def up do
    create_role_and_grants()

    execute """
    CREATE OR REPLACE FUNCTION app_org_id() RETURNS uuid AS $$
      SELECT nullif(current_setting('app.current_organization_id', true), '')::uuid
    $$ LANGUAGE sql STABLE
    """

    execute """
    CREATE OR REPLACE FUNCTION app_privileged() RETURNS boolean AS $$
      SELECT coalesce(current_setting('app.current_user_role', true), '') IN ('admin', 'system')
    $$ LANGUAGE sql STABLE
    """

    for table <- @old_policies do
      execute "DROP POLICY IF EXISTS #{table}_organization_isolation ON #{table}"
    end

    protect("organizations", "id = app_org_id()")

    for table <- @direct do
      protect(table, "organization_id = app_org_id()")
    end

    for {table, column, parent} <- @children do
      protect(table, "#{column} IN (SELECT id FROM #{parent})")
    end
  end

  def down do
    for table <- ["organizations" | @direct] ++ Enum.map(@children, &elem(&1, 0)) do
      execute "DROP POLICY IF EXISTS tenant_isolation ON #{table}"

      unless table in @old_policies do
        execute "ALTER TABLE #{table} DISABLE ROW LEVEL SECURITY"
      end
    end

    for table <- @old_policies do
      execute """
      CREATE POLICY #{table}_organization_isolation ON #{table}
      USING (
        organization_id = current_setting('app.current_organization_id', true)::uuid
        OR current_setting('app.current_user_role', true) = 'admin'
      )
      """
    end

    execute "DROP FUNCTION IF EXISTS app_privileged()"
    execute "DROP FUNCTION IF EXISTS app_org_id()"
    # The role is shared by the whole cluster, so it is left in place.
  end

  defp protect(table, visible) do
    execute "ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY"
    execute "DROP POLICY IF EXISTS tenant_isolation ON #{table}"

    execute """
    CREATE POLICY tenant_isolation ON #{table}
    USING (app_privileged() OR #{visible})
    WITH CHECK (app_privileged() OR #{visible})
    """
  end

  # Creating a role needs CREATEROLE. Where the migrating user lacks it, create
  # `afya_fit_app` yourself and re-run the GRANT statements below.
  defp create_role_and_grants do
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '#{@app_role}') THEN
        CREATE ROLE #{@app_role} NOLOGIN;
      END IF;

      GRANT #{@app_role} TO CURRENT_USER;
      GRANT USAGE ON SCHEMA public TO #{@app_role};
      GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO #{@app_role};
      GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO #{@app_role};
      ALTER DEFAULT PRIVILEGES IN SCHEMA public
        GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO #{@app_role};
      ALTER DEFAULT PRIVILEGES IN SCHEMA public
        GRANT USAGE, SELECT ON SEQUENCES TO #{@app_role};
    EXCEPTION WHEN insufficient_privilege THEN
      RAISE NOTICE 'could not set up role #{@app_role}; create it and grant table access by hand';
    END
    $$
    """
  end
end
