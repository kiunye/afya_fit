defmodule AfyaFit.Repo.Migrations.PromoteFirstTrainersToOrgAdmin do
  use Ecto.Migration

  # Mirrors AfyaFit.Accounts.promote_first_trainers/0 in SQL so the migration
  # does not depend on application code. The promoted users are recorded so
  # `down` demotes only them, not org admins created later.
  def up do
    create table(:org_admin_backfill, primary_key: false) do
      add :user_id, :binary_id, primary_key: true
    end

    execute """
    INSERT INTO org_admin_backfill (user_id)
    SELECT DISTINCT ON (organization_id) id
    FROM users
    WHERE role = 'trainer'
      AND organization_id NOT IN (
        SELECT organization_id FROM users
        WHERE role = 'org_admin' AND organization_id IS NOT NULL
      )
    ORDER BY organization_id, inserted_at, id
    """

    execute """
    UPDATE users SET role = 'org_admin', updated_at = now()
    WHERE id IN (SELECT user_id FROM org_admin_backfill)
    """
  end

  def down do
    execute """
    UPDATE users SET role = 'trainer', updated_at = now()
    WHERE role = 'org_admin' AND id IN (SELECT user_id FROM org_admin_backfill)
    """

    drop table(:org_admin_backfill)
  end
end
