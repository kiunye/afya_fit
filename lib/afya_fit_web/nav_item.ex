defmodule AfyaFitWeb.NavItem do
  @moduledoc """
  One entry in the navigation. `AfyaFitWeb.Access` keeps the catalogue and
  decides which entries a person sees.

    * `roles` says who may see it, `permission` (`{action, resource}`) what they
      must also be allowed to do;
    * `phone` is where it sits on a phone: a bottom `:tab`, or under `:more`;
    * `pro` marks a feature the plan does not include yet. It stays visible so it
      can be discovered. Filled in per person, never in the catalogue.
  """

  @enforce_keys [:key, :label, :icon, :path, :roles]
  defstruct [:key, :label, :icon, :path, :roles, permission: nil, phone: :more, pro: false]

  @type t :: %__MODULE__{
          key: atom(),
          label: String.t(),
          icon: atom(),
          path: String.t(),
          roles: [atom()],
          permission: {atom(), atom()} | nil,
          phone: :tab | :more,
          pro: boolean()
        }
end
