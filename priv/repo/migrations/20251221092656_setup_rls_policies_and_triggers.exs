defmodule AfyaFit.Repo.Migrations.SetupRlsPoliciesAndTriggers do
  use Ecto.Migration

  def up do
    # ============================================================================
    # TRIGGERS FOR UPDATED_AT
    # ============================================================================

    # Create function to update updated_at timestamp
    execute """
    CREATE OR REPLACE FUNCTION update_updated_at_column()
    RETURNS TRIGGER AS $$
    BEGIN
        NEW.updated_at = NOW();
        RETURN NEW;
    END;
    $$ language 'plpgsql';
    """

    # Apply triggers to all tables with updated_at columns
    execute """
    CREATE TRIGGER update_organizations_updated_at
    BEFORE UPDATE ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """

    execute """
    CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """

    execute """
    CREATE TRIGGER update_trainer_clients_updated_at
    BEFORE UPDATE ON trainer_clients
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """

    execute """
    CREATE TRIGGER update_workout_plans_updated_at
    BEFORE UPDATE ON workout_plans
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """

    execute """
    CREATE TRIGGER update_client_workouts_updated_at
    BEFORE UPDATE ON client_workouts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """

    execute """
    CREATE TRIGGER update_nutrition_plans_updated_at
    BEFORE UPDATE ON nutrition_plans
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """

    execute """
    CREATE TRIGGER update_progress_entries_updated_at
    BEFORE UPDATE ON progress_entries
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """

    execute """
    CREATE TRIGGER update_tasks_updated_at
    BEFORE UPDATE ON tasks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """

    execute """
    CREATE TRIGGER update_calendar_events_updated_at
    BEFORE UPDATE ON calendar_events
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """

    execute """
    CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """

    execute """
    CREATE TRIGGER update_invoices_updated_at
    BEFORE UPDATE ON invoices
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """

    execute """
    CREATE TRIGGER update_user_preferences_updated_at
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """

    execute """
    CREATE TRIGGER update_device_tokens_updated_at
    BEFORE UPDATE ON device_tokens
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
    """

    # ============================================================================
    # ROW LEVEL SECURITY (RLS) POLICIES
    # ============================================================================

    # Enable RLS on tenant-scoped tables
    execute "ALTER TABLE users ENABLE ROW LEVEL SECURITY;"
    execute "ALTER TABLE workout_plans ENABLE ROW LEVEL SECURITY;"
    execute "ALTER TABLE nutrition_plans ENABLE ROW LEVEL SECURITY;"
    execute "ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;"
    execute "ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;"
    execute "ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;"

    # Create RLS policies for organization isolation
    # These policies use a session variable 'app.current_organization_id' that should be
    # set by the application before queries. The application layer should set this using:
    # Ecto.Adapters.SQL.query(Repo, "SET LOCAL app.current_organization_id = $1", [org_id])

    # Users: Users can only see users from their own organization
    execute """
    CREATE POLICY users_organization_isolation ON users
    FOR ALL
    USING (
      organization_id = current_setting('app.current_organization_id', true)::uuid
      OR current_setting('app.current_user_role', true) = 'admin'
    );
    """

    # Workout Plans: Users can only see workout plans from their organization
    execute """
    CREATE POLICY workout_plans_organization_isolation ON workout_plans
    FOR ALL
    USING (
      organization_id = current_setting('app.current_organization_id', true)::uuid
    );
    """

    # Nutrition Plans: Users can only see nutrition plans from their organization
    execute """
    CREATE POLICY nutrition_plans_organization_isolation ON nutrition_plans
    FOR ALL
    USING (
      organization_id = current_setting('app.current_organization_id', true)::uuid
    );
    """

    # Tasks: Users can only see tasks from their organization
    execute """
    CREATE POLICY tasks_organization_isolation ON tasks
    FOR ALL
    USING (
      organization_id = current_setting('app.current_organization_id', true)::uuid
    );
    """

    # Calendar Events: Users can only see calendar events from their organization
    execute """
    CREATE POLICY calendar_events_organization_isolation ON calendar_events
    FOR ALL
    USING (
      organization_id = current_setting('app.current_organization_id', true)::uuid
    );
    """

    # Activity Logs: Users can only see activity logs from their organization
    execute """
    CREATE POLICY activity_logs_organization_isolation ON activity_logs
    FOR ALL
    USING (
      organization_id = current_setting('app.current_organization_id', true)::uuid
    );
    """

    # Note: For production use, you may want to add more granular policies that consider:
    # - Trainer-client relationships (trainers can see their clients' data)
    # - Client access (clients can only see their own data)
    # - Role-based access (admins can see all data in their organization)
    #
    # These can be added as additional policies or handled at the application layer
    # using Ecto queries with proper WHERE clauses.
  end

  def down do
    # Drop RLS policies
    execute "DROP POLICY IF EXISTS users_organization_isolation ON users;"
    execute "DROP POLICY IF EXISTS workout_plans_organization_isolation ON workout_plans;"
    execute "DROP POLICY IF EXISTS nutrition_plans_organization_isolation ON nutrition_plans;"
    execute "DROP POLICY IF EXISTS tasks_organization_isolation ON tasks;"
    execute "DROP POLICY IF EXISTS calendar_events_organization_isolation ON calendar_events;"
    execute "DROP POLICY IF EXISTS activity_logs_organization_isolation ON activity_logs;"

    # Disable RLS
    execute "ALTER TABLE users DISABLE ROW LEVEL SECURITY;"
    execute "ALTER TABLE workout_plans DISABLE ROW LEVEL SECURITY;"
    execute "ALTER TABLE nutrition_plans DISABLE ROW LEVEL SECURITY;"
    execute "ALTER TABLE tasks DISABLE ROW LEVEL SECURITY;"
    execute "ALTER TABLE calendar_events DISABLE ROW LEVEL SECURITY;"
    execute "ALTER TABLE activity_logs DISABLE ROW LEVEL SECURITY;"

    # Drop triggers
    execute "DROP TRIGGER IF EXISTS update_organizations_updated_at ON organizations;"
    execute "DROP TRIGGER IF EXISTS update_users_updated_at ON users;"
    execute "DROP TRIGGER IF EXISTS update_trainer_clients_updated_at ON trainer_clients;"
    execute "DROP TRIGGER IF EXISTS update_workout_plans_updated_at ON workout_plans;"
    execute "DROP TRIGGER IF EXISTS update_client_workouts_updated_at ON client_workouts;"
    execute "DROP TRIGGER IF EXISTS update_nutrition_plans_updated_at ON nutrition_plans;"
    execute "DROP TRIGGER IF EXISTS update_progress_entries_updated_at ON progress_entries;"
    execute "DROP TRIGGER IF EXISTS update_tasks_updated_at ON tasks;"
    execute "DROP TRIGGER IF EXISTS update_calendar_events_updated_at ON calendar_events;"
    execute "DROP TRIGGER IF EXISTS update_subscriptions_updated_at ON subscriptions;"
    execute "DROP TRIGGER IF EXISTS update_invoices_updated_at ON invoices;"
    execute "DROP TRIGGER IF EXISTS update_user_preferences_updated_at ON user_preferences;"
    execute "DROP TRIGGER IF EXISTS update_device_tokens_updated_at ON device_tokens;"

    # Drop function
    execute "DROP FUNCTION IF EXISTS update_updated_at_column();"
  end
end
