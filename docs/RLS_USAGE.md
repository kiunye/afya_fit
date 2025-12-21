# Row-Level Security (RLS) Usage Guide

## Overview

Row-Level Security (RLS) policies have been set up to ensure multi-tenant data isolation at the database level. This provides an additional layer of security beyond application-level filtering.

## How It Works

RLS policies use PostgreSQL session variables to filter data:
- `app.current_organization_id` - Filters data by organization
- `app.current_user_role` - Used for role-based access control

## Setting RLS Context

### Using the Helper Module

The `AfyaFit.Repo.RLSHelper` module provides convenient functions to set RLS context:

```elixir
# In a controller or LiveView, set context from current user
defmodule AfyaFitWeb.SomeController do
  def index(conn, _params) do
    user = conn.assigns.current_scope.user
    
    # Set RLS context before queries
    AfyaFit.Repo.RLSHelper.set_organization_context(conn, user)
    
    # Now queries will be filtered by RLS
    workouts = AfyaFit.Workouts.list_workout_plans()
    
    render(conn, :index, workouts: workouts)
  end
end
```

### Using in Transactions

```elixir
AfyaFit.Repo.transaction(fn ->
  AfyaFit.Repo.RLSHelper.set_organization_id(AfyaFit.Repo, organization_id)
  AfyaFit.Repo.RLSHelper.set_user_role(AfyaFit.Repo, "trainer")
  
  # All queries in this transaction will be filtered by RLS
  workouts = AfyaFit.Workouts.list_workout_plans()
  # ...
end)
```

### Manual Context Setting

```elixir
# Set organization ID
Ecto.Adapters.SQL.query!(
  AfyaFit.Repo,
  "SET LOCAL app.current_organization_id = $1",
  [organization_id]
)

# Set user role
Ecto.Adapters.SQL.query!(
  AfyaFit.Repo,
  "SET LOCAL app.current_user_role = $1",
  [user_role]
)
```

## Important Notes

1. **Session Variables**: The `SET LOCAL` command sets variables for the current transaction only. They are automatically cleared when the transaction ends.

2. **Application-Level Filtering**: RLS is a defense-in-depth measure. You should still filter queries at the application level using Ecto queries:

```elixir
# Good: Application-level filtering + RLS
def list_workout_plans(organization_id) do
  WorkoutPlan
  |> where([w], w.organization_id == ^organization_id)
  |> Repo.all()
end
```

3. **Testing**: In tests, you may need to set RLS context or disable RLS:

```elixir
# In test setup
setup do
  # Set RLS context for tests
  AfyaFit.Repo.RLSHelper.set_organization_id(AfyaFit.Repo, org.id)
  :ok
end
```

## Tables with RLS Enabled

The following tables have RLS enabled:
- `users`
- `workout_plans`
- `nutrition_plans`
- `tasks`
- `calendar_events`
- `activity_logs`

## Future Enhancements

Consider adding more granular policies for:
- Trainer-client relationships (trainers can see their clients' data)
- Client access (clients can only see their own data)
- Role-based access (admins can see all data in their organization)

These can be added as additional policies or handled at the application layer.
