defmodule AfyaFit.RLSCoverageTest do
  use AfyaFit.DataCase, async: true

  # Tables that hold no tenant data, or that the app only reaches as the owner.
  @unprotected ~w(exercises schema_migrations oban_jobs oban_peers org_admin_backfill)

  test "every table has row-level security unless it is listed as tenant-free" do
    %{rows: rows} =
      Ecto.Adapters.SQL.query!(
        AfyaFit.Repo,
        """
        SELECT c.relname
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relkind = 'r' AND NOT c.relrowsecurity
        ORDER BY c.relname
        """,
        []
      )

    unprotected = rows |> List.flatten() |> Kernel.--(@unprotected)

    assert unprotected == [],
           "tables without row-level security: #{inspect(unprotected)}. " <>
             "Add them to the tenant_isolation migration, or to @unprotected if they hold no tenant data."
  end
end
