defmodule AfyaFitWeb.TrainerLive.Workouts do
  @moduledoc """
  Workouts: the library of plans a trainer builds and shares.
  """
  use AfyaFitWeb, :live_view

  import AfyaFitWeb.SignComponents

  alias AfyaFit.Authorization
  alias AfyaFit.Workouts
  alias AfyaFit.Workouts.WorkoutPlan
  alias AfyaFitWeb.Access

  @tabs ~w(mine shared templates)

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> Access.guard(:list, :workout_plan)
      |> assign(:page_title, "Workouts")
      |> assign(:form, nil)
      |> assign(:workout_plan, nil)
      |> assign(:tab, "mine")
      |> assign(:confirm_delete?, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    if socket.assigns.denied do
      {:noreply, socket}
    else
      {:noreply, apply_action(socket, socket.assigns.live_action, params)}
    end
  end

  defp apply_action(socket, :index, params) do
    scope = socket.assigns.current_scope
    tab = if params["tab"] in @tabs, do: params["tab"], else: "mine"
    plans = scope |> Workouts.list_workout_plans_for() |> in_tab(tab, scope.user.id)

    socket
    |> assign(:tab, tab)
    |> assign(:total, length(Workouts.list_workout_plans_for(scope)))
    |> assign(:can_create?, Authorization.can?(scope, :create, :workout_plan))
    |> assign(:empty?, plans == [])
    |> stream(:plans, Enum.sort_by(plans, & &1.inserted_at, {:desc, DateTime}), reset: true)
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope

    case Authorization.authorize(scope, :create, :workout_plan) do
      :ok ->
        assign(
          socket,
          :form,
          to_form(WorkoutPlan.changeset(%WorkoutPlan{}, %{}), as: "workout_plan")
        )

      error ->
        socket |> Access.flash_denial(error) |> push_navigate(to: ~p"/trainer/workouts")
    end
  end

  defp apply_action(socket, action, %{"id" => id}) when action in [:show, :edit] do
    scope = socket.assigns.current_scope
    plan_action = if action == :show, do: :read, else: :update

    case fetch_plan(scope, plan_action, id) do
      {:ok, plan} ->
        socket
        |> assign(:workout_plan, plan)
        |> assign(:confirm_delete?, false)
        |> assign(:can_update?, Authorization.can?(scope, :update, plan))
        |> assign(:can_delete?, Authorization.can?(scope, :delete, plan))
        |> assign(:can_duplicate?, Authorization.can?(scope, :duplicate, plan))
        |> assign(
          :form,
          action == :edit && to_form(WorkoutPlan.changeset(plan, %{}), as: "workout_plan")
        )

      {:denied, denied} ->
        assign(socket, :denied, denied)
    end
  end

  defp fetch_plan(scope, action, id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %WorkoutPlan{} = plan <- Workouts.get_workout_plan(uuid),
         :ok <- Authorization.authorize(scope, action, plan) do
      {:ok, plan}
    else
      {:error, _} = error -> {:denied, Access.denial(scope, error)}
      _ -> {:denied, Access.denial(scope, {:error, :not_found})}
    end
  end

  defp in_tab(plans, "mine", user_id),
    do: Enum.filter(plans, &(&1.trainer_id == user_id and not &1.is_template))

  defp in_tab(plans, "shared", user_id),
    do: Enum.filter(plans, &(&1.trainer_id != user_id and &1.is_public))

  defp in_tab(plans, "templates", _user_id), do: Enum.filter(plans, & &1.is_template)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:workouts}>
      <.denied_sign :if={@denied} kind={elem(@denied, 0)} message={elem(@denied, 1)} />
      <div :if={!@denied}>
        <.workouts_index :if={@live_action == :index} {assigns} />
        <.workouts_form :if={@live_action in [:new, :edit] && @form} {assigns} />
        <.workouts_show :if={@live_action == :show && @workout_plan} {assigns} />
      </div>
    </Layouts.app>
    """
  end

  defp workouts_index(assigns) do
    ~H"""
    <.page_header>
      Workouts
      <:subtitle>
        <b class="text-ink">{@total} {if @total == 1, do: "plan", else: "plans"}.</b>
        Build once, assign to many clients.
      </:subtitle>
    </.page_header>

    <.sign_group label="Plans">
      <:actions>
        <.sign_action :if={@can_create?} id="new-plan" primary navigate={~p"/trainer/workouts/new"}>
          New plan
        </.sign_action>
        
        <span :if={!@can_create?} class="flex items-center gap-3 text-sm text-ink-2">
          Paused until payment clears
          <.sign_action id="new-plan" aria-disabled="true">New plan</.sign_action>
        </span>
      </:actions>
      
      <nav aria-label="Plan type" class="flex gap-2 px-4 pb-3 sm:px-[26px]">
        <.link
          :for={
            {label, value} <- [{"Mine", "mine"}, {"Shared", "shared"}, {"Templates", "templates"}]
          }
          patch={~p"/trainer/workouts?tab=#{value}"}
          aria-current={@tab == value && "true"}
          class={[
            "rounded-control border-2 px-3 py-1 text-xs font-bold uppercase tracking-[.06em]",
            @tab == value && "border-white bg-white text-field-0",
            @tab != value && "border-line/50 text-ink-2 hover:border-white hover:text-white"
          ]}
        >
          {label}
        </.link>
      </nav>
      
      <div id="plans" phx-update="stream">
        <div
          id="plans-empty"
          class="hidden border-b border-line/40 px-4 py-6 text-ink-2 only:block sm:px-[26px]"
        >
          <%= case @tab do %>
            <% "mine" -> %>
              No workout plans yet. Build your own, or start from a template.
            <% "shared" -> %>
              Nobody has shared a plan with the team yet.
            <% "templates" -> %>
              No templates yet. Mark a plan as a template to reuse it.
          <% end %>
        </div>
        
        <.sign
          :for={{id, plan} <- @streams.plans}
          id={id}
          icon={:workouts}
          time={Calendar.strftime(plan.updated_at, "%-d %b")}
          time_label="Updated"
        >
          <:title>{plan.name}</:title>
           {plan.duration_weeks} weeks · {plan.difficulty}
          <:actions>
            <.sign_action navigate={~p"/trainer/workouts/#{plan.id}"}>Open</.sign_action>
          </:actions>
        </.sign>
      </div>
    </.sign_group>
    """
  end

  defp workouts_form(assigns) do
    ~H"""
    <.page_header>
      {if @live_action == :new, do: "New plan", else: "Edit plan"}
      <:subtitle>
        {if @live_action == :new,
          do: "Weeks, difficulty and who can see it.",
          else: @workout_plan.name}
      </:subtitle>
    </.page_header>

    <.form
      for={@form}
      id="workout-form"
      phx-submit={if @live_action == :new, do: "save", else: "update"}
      phx-change="validate"
      class="max-w-2xl px-4 py-6 sm:px-[26px]"
    >
      <.input field={@form[:name]} type="text" label="Plan name" required />
      <.input field={@form[:description]} type="textarea" label="Description" />
      <div class="grid gap-x-6 sm:grid-cols-2">
        <.input
          field={@form[:duration_weeks]}
          type="number"
          label="Duration (weeks)"
          min="1"
          required
        />
        <.input
          field={@form[:difficulty]}
          type="select"
          label="Difficulty"
          prompt="Choose"
          options={[
            {"Beginner", "beginner"},
            {"Intermediate", "intermediate"},
            {"Advanced", "advanced"}
          ]}
          required
        />
      </div>
       <.input field={@form[:is_template]} type="checkbox" label="Save as a template" />
      <.input
        field={@form[:is_public]}
        type="checkbox"
        label="Share with other trainers in the organisation"
      />
      <div class="mt-6 flex flex-wrap gap-3">
        <.button type="submit" variant="primary">
          {if @live_action == :new, do: "Create plan", else: "Save"}
        </.button>
        <.button navigate={
          if @live_action == :new,
            do: ~p"/trainer/workouts",
            else: ~p"/trainer/workouts/#{@workout_plan.id}"
        }>
          Cancel
        </.button>
      </div>
    </.form>
    """
  end

  defp workouts_show(assigns) do
    ~H"""
    <.page_header>
      {@workout_plan.name}
      <:subtitle>{@workout_plan.description || "No description."}</:subtitle>
      
      <:actions>
        <.sign_action
          :if={@can_update?}
          id="edit-plan"
          navigate={~p"/trainer/workouts/#{@workout_plan.id}/edit"}
        >
          Edit
        </.sign_action>
        
        <.sign_action :if={@can_duplicate?} id="duplicate-plan" phx-click="duplicate">
          Duplicate
        </.sign_action>
      </:actions>
    </.page_header>

    <.sign_group label="Details">
      <div class="px-4 sm:px-[26px]">
        <.list>
          <:item title="Duration">{@workout_plan.duration_weeks} weeks</:item>
          
          <:item title="Difficulty"><span class="capitalize">{@workout_plan.difficulty}</span></:item>
          
          <:item title="Template">{if @workout_plan.is_template, do: "Yes", else: "No"}</:item>
          
          <:item title="Shared">
            {if @workout_plan.is_public, do: "Yes, with the organisation", else: "No"}
          </:item>
        </.list>
      </div>
    </.sign_group>

    <.sign_group :if={@can_delete?} label="Delete">
      <.sign :if={!@confirm_delete?} id="delete-plan" icon={:alert} draw={false}>
        <:title>Delete this plan</:title>
        Clients keep their history; the plan stops showing for new sessions.
        <:actions>
          <.sign_action id="ask-delete" phx-click="ask_delete">Delete</.sign_action>
        </:actions>
      </.sign>
      
      <.sign :if={@confirm_delete?} id="delete-confirm" icon={:alert} state={:next} draw={false}>
        <:title>Delete {@workout_plan.name}?</:title>
        This cannot be undone.
        <:actions>
          <.sign_action id="confirm-delete" primary phx-click="delete">Delete plan</.sign_action>
          
          <.sign_action id="keep-plan" phx-click="keep">Keep</.sign_action>
        </:actions>
      </.sign>
    </.sign_group>
    """
  end

  @impl true
  def handle_event("validate", %{"workout_plan" => params}, socket) do
    changeset =
      case socket.assigns.live_action do
        :new -> WorkoutPlan.changeset(%WorkoutPlan{}, own(params, socket))
        :edit -> WorkoutPlan.update_changeset(socket.assigns.workout_plan, params)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: "workout_plan"))}
  end

  def handle_event("save", %{"workout_plan" => params}, socket) do
    scope = socket.assigns.current_scope

    with :ok <- Authorization.authorize(scope, :create, :workout_plan),
         {:ok, plan} <-
           Workouts.create_workout_plan(own(params, socket)) do
      {:noreply,
       socket
       |> put_flash(:info, "Plan created.")
       |> push_navigate(to: ~p"/trainer/workouts/#{plan.id}")}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "workout_plan"))}

      error ->
        {:noreply, Access.flash_denial(socket, error)}
    end
  end

  def handle_event("update", %{"workout_plan" => params}, socket) do
    scope = socket.assigns.current_scope
    plan = socket.assigns.workout_plan

    with :ok <- Authorization.authorize(scope, :update, plan),
         {:ok, plan} <- Workouts.update_workout_plan(plan, params) do
      {:noreply,
       socket |> put_flash(:info, "Saved.") |> push_navigate(to: ~p"/trainer/workouts/#{plan.id}")}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "workout_plan"))}

      error ->
        {:noreply, Access.flash_denial(socket, error)}
    end
  end

  def handle_event("duplicate", _params, socket) do
    scope = socket.assigns.current_scope
    original = socket.assigns.workout_plan

    attrs = %{
      "name" => "#{original.name} (Copy)",
      "description" => original.description,
      "duration_weeks" => original.duration_weeks,
      "difficulty" => original.difficulty,
      "is_template" => false
    }

    with :ok <- Authorization.authorize(scope, :duplicate, original),
         :ok <- Authorization.authorize(scope, :create, :workout_plan),
         {:ok, copy} <- Workouts.create_workout_plan(own(attrs, socket)) do
      {:noreply,
       socket
       |> put_flash(:info, "Duplicated.")
       |> push_navigate(to: ~p"/trainer/workouts/#{copy.id}")}
    else
      error -> {:noreply, Access.flash_denial(socket, error)}
    end
  end

  def handle_event("ask_delete", _params, socket),
    do: {:noreply, assign(socket, :confirm_delete?, true)}

  def handle_event("keep", _params, socket),
    do: {:noreply, assign(socket, :confirm_delete?, false)}

  def handle_event("delete", _params, socket) do
    plan = socket.assigns.workout_plan

    with :ok <- Authorization.authorize(socket.assigns.current_scope, :delete, plan),
         {:ok, _plan} <- Workouts.delete_workout_plan(plan) do
      {:noreply,
       socket |> put_flash(:info, "Plan deleted.") |> push_navigate(to: ~p"/trainer/workouts")}
    else
      error -> {:noreply, socket |> assign(:confirm_delete?, false) |> Access.flash_denial(error)}
    end
  end

  defp own(params, socket) do
    user = socket.assigns.current_scope.user

    params
    |> Map.put("organization_id", user.organization_id)
    |> Map.put("trainer_id", user.id)
  end
end
