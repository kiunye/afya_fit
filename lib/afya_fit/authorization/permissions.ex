defmodule AfyaFit.Authorization.Permissions do
  @moduledoc """
  The role-based part of authorization: which actions each role may attempt on
  each resource type. Attribute rules (ownership, relationships, visibility)
  are applied afterwards by `AfyaFit.Authorization.Policy`.
  """

  @crud [:list, :read, :create, :update, :delete]
  @read_actions [:list, :read, :analytics]

  @trainer %{
    client: @crud ++ [:invite],
    workout_plan: @crud ++ [:duplicate],
    client_workout: @crud ++ [:complete],
    nutrition_plan: @crud,
    progress_entry: @crud ++ [:analytics, :upload_photo],
    task: @crud ++ [:complete, :automate],
    calendar_event: @crud
  }

  @matrix %{
    admin: %{
      client: [:list, :read],
      trainer: @crud,
      workout_plan: [:list, :read],
      client_workout: [:list, :read],
      nutrition_plan: [:list, :read],
      progress_entry: [:list, :read],
      task: [:list, :read],
      calendar_event: [:list, :read],
      subscription: [:read, :manage],
      admin_panel: [:access, :manage]
    },
    org_admin:
      Map.merge(@trainer, %{
        client: @trainer.client ++ [:reassign],
        trainer: @crud,
        subscription: [:read, :manage]
      }),
    trainer: @trainer,
    client: %{
      client: [:read, :update],
      client_workout: [:list, :read, :complete],
      nutrition_plan: [:list, :read],
      progress_entry: [:list, :read, :create, :update, :upload_photo],
      task: [:list, :read, :complete],
      calendar_event: [:list, :read],
      client_subscription: [:read, :update]
    }
  }

  @type resource :: atom()
  @type action :: atom()

  @doc "Every resource type and action the role may attempt."
  @spec for_role(AfyaFit.Authorization.Scope.role()) :: %{resource() => [action()]}
  def for_role(role), do: Map.get(@matrix, role, %{})

  @spec allowed?(AfyaFit.Authorization.Scope.role(), resource(), action()) :: boolean()
  def allowed?(role, resource, action), do: action in Map.get(for_role(role), resource, [])

  @doc "Actions that only read data, which stay available in read-only billing states."
  @spec read_action?(action()) :: boolean()
  def read_action?(action), do: action in @read_actions
end
