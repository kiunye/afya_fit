# Row-level security

Postgres row-level security (RLS) is the second wall behind `AfyaFit.Authorization`.
If a query forgets its organization filter, the database returns nothing instead of
another tenant's rows. It is off by default.

## How it works

- Every tenant table has a `tenant_isolation` policy (migration
  `add_tenant_isolation_policies`). Tables with an `organization_id` check it
  directly; child tables (plans' exercises, progress photos, invoices, ...) are
  visible when their parent row is.
- Policies read `app.current_organization_id` and `app.current_user_role`. The
  roles `admin` (platform admin) and `system` see every row.
- Table owners bypass RLS, so with enforcement on the app runs as the non-owner
  role `afya_fit_app` (`SET ROLE` on connect). The migration creates it
  (`NOLOGIN`) and grants table access; it needs `CREATEROLE`, otherwise create
  the role and re-run the grants by hand.
- `AfyaFit.RLS.with_scope/2` and `unscoped/1` pin a connection, set the context
  and reset it. They are applied for you to controller actions, LiveView
  callbacks (`AfyaFit.Repo.Wrap`) and Oban jobs. Sign-in, token lookup,
  registration, webhooks and jobs run `unscoped` because no organization is
  known yet. Anything outside both sees no rows.

## Turning it on

```
RLS_ENFORCE=true RLS_APP_ROLE=afya_fit_app   # runtime
```

Run migrations with `RLS_ENFORCE` unset: they need the owner role.
Try it on staging first and watch for empty results where data is expected;
that points at a code path that runs outside a scope (for example a `Task` that
starts a new process, which does not inherit the context).

`RLS_ENFORCE=true mix test` runs the whole suite as the non-owner role.

## Rolling back

Unset `RLS_ENFORCE`. The policies stay in place but the owner role ignores them.
`mix ecto.rollback --step 1` removes the policies and functions; the role is left
because it is shared by the cluster.
