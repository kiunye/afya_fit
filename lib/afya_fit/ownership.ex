defmodule AfyaFit.Ownership do
  @moduledoc """
  Update changesets must not be able to move a record to another owner,
  trainer, client or organization, whatever a caller passes in.

  Each schema declares which of its fields are ownership fields and builds its
  `update_changeset/2` from its `changeset/2` with them removed, so callers
  (API controllers, LiveViews, workers) cannot forget to strip them.
  """

  @doc "Removes `fields` from `attrs`, whether the keys are atoms or strings."
  @spec without(map(), [atom()]) :: map()
  def without(attrs, fields) when is_map(attrs) do
    Map.drop(attrs, Enum.flat_map(fields, &[&1, Atom.to_string(&1)]))
  end
end
