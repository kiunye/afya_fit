defmodule AfyaFit.Repo.Migrations.MakeUserTimezoneOptional do
  use Ecto.Migration

  # A user's time zone is now `NULL` until they (or their browser) tell us, and
  # shown as UTC meanwhile. Before, "UTC" was both the default and a real choice,
  # so nothing could tell the two apart. Time zones only started being used with
  # the previous release, so every existing "UTC" is the default, not a choice.
  def up do
    execute "ALTER TABLE users ALTER COLUMN timezone DROP DEFAULT"
    execute "UPDATE users SET timezone = NULL WHERE timezone = 'UTC'"
  end

  def down do
    execute "UPDATE users SET timezone = 'UTC' WHERE timezone IS NULL"
    execute "ALTER TABLE users ALTER COLUMN timezone SET DEFAULT 'UTC'"
  end
end
