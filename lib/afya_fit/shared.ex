defmodule AfyaFit.Shared do
  @moduledoc """
  The Shared context.
  """
  import Ecto.Query, warn: false
  alias AfyaFit.Repo
  alias AfyaFit.Shared.{ActivityLog, Tag}

  def list_tags(organization_id) do
    Tag
    |> where([t], t.organization_id == ^organization_id or is_nil(t.organization_id))
    |> Repo.all()
  end

  def create_tag(attrs \\ %{}) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  def create_activity_log(attrs \\ %{}) do
    %ActivityLog{}
    |> ActivityLog.changeset(attrs)
    |> Repo.insert()
  end
end
