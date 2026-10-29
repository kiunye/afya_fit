defmodule AfyaFitWeb.TrainerLive.Nutrition do
  @moduledoc """
  Nutrition: meal plans for clients. A Pro feature: on Free the existing plans
  stay readable and creating one is shown as a closed sign.
  """
  use AfyaFitWeb, :live_view

  import AfyaFitWeb.SignComponents

  alias AfyaFit.{Authorization, Clients, Nutrition}
  alias AfyaFit.Authorization.Scope
  alias AfyaFit.Nutrition.NutritionPlan
  alias AfyaFitWeb.Access

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> Access.guard(:list, :nutrition_plan)
      |> assign(:page_title, "Nutrition")
      |> assign(:form, nil)
      |> assign(:nutrition_plan, nil)
      |> assign(:clients, [])
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

  defp apply_action(socket, :index, _params) do
    scope = socket.assigns.current_scope
    plans = Nutrition.list_nutrition_plans_for(scope)

    socket
    |> assign(:total, length(plans))
    |> assign(:create_state, create_state(scope))
    |> assign(:can_upgrade?, Authorization.can?(scope, :manage, :subscription))
    |> assign(:empty?, plans == [])
    |> stream(:plans, Enum.sort_by(plans, & &1.inserted_at, {:desc, DateTime}), reset: true)
  end

  defp apply_action(socket, :new, _params) do
    scope = socket.assigns.current_scope

    case Authorization.authorize(scope, :create, :nutrition_plan) do
      :ok ->
        socket
        |> assign(:clients, Clients.list_clients_for(scope))
        |> assign(
          :form,
          to_form(NutritionPlan.changeset(%NutritionPlan{}, %{}), as: "nutrition_plan")
        )

      _blocked ->
        push_navigate(socket, to: ~p"/trainer/nutrition")
    end
  end

  defp apply_action(socket, action, %{"id" => id}) when action in [:show, :edit] do
    scope = socket.assigns.current_scope
    plan_action = if action == :show, do: :read, else: :update

    case fetch_plan(scope, plan_action, id) do
      {:ok, plan} ->
        socket
        |> assign(:nutrition_plan, plan)
        |> assign(:confirm_delete?, false)
        |> assign(:clients, Clients.list_clients_for(scope))
        |> assign(:can_update?, Authorization.can?(scope, :update, plan))
        |> assign(:can_delete?, Authorization.can?(scope, :delete, plan))
        |> assign(
          :form,
          action == :edit && to_form(NutritionPlan.changeset(plan, %{}), as: "nutrition_plan")
        )

      {:denied, denied} ->
        assign(socket, :denied, denied)
    end
  end

  defp fetch_plan(scope, action, id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %NutritionPlan{} = plan <- Nutrition.get_nutrition_plan(uuid),
         :ok <- Authorization.authorize(scope, action, plan) do
      {:ok, plan}
    else
      {:error, _} = error -> {:denied, Access.denial(scope, error)}
      _ -> {:denied, Access.denial(scope, {:error, :not_found})}
    end
  end

  # :ok, :closed (not on this plan) or :paused (read-only account).
  defp create_state(scope) do
    case Authorization.authorize(scope, :create, :nutrition_plan) do
      :ok -> :ok
      {:error, {:upgrade_required, _}} -> :closed
      {:error, {:subscription_inactive, _}} -> :paused
      {:error, _} -> :hidden
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:nutrition}>
      <.denied_sign :if={@denied} kind={elem(@denied, 0)} message={elem(@denied, 1)} />
      <div :if={!@denied}>
        <.nutrition_index :if={@live_action == :index} {assigns} />
        <.nutrition_form :if={@live_action in [:new, :edit] && @form} {assigns} />
        <.nutrition_show :if={@live_action == :show && @nutrition_plan} {assigns} />
      </div>
    </Layouts.app>
    """
  end

  defp nutrition_index(assigns) do
    ~H"""
    <.page_header>
      Nutrition
      <:subtitle>
        <b class="text-ink">{@total} {if @total == 1, do: "plan", else: "plans"}.</b>
        Calories and meals for each client.
      </:subtitle>
    </.page_header>

    <.sign_group label="Plans">
      <:actions>
        <.sign_action
          :if={@create_state == :ok}
          id="new-plan"
          primary
          navigate={~p"/trainer/nutrition/new"}
        >
          New plan
        </.sign_action>
        
        <span :if={@create_state == :paused} class="flex items-center gap-3 text-sm text-ink-2">
          Paused until payment clears
          <.sign_action id="new-plan" aria-disabled="true">New plan</.sign_action>
        </span>
      </:actions>
      
      <.closed_sign
        :if={@create_state == :closed}
        id="nutrition-closed"
        icon={:nutrition}
        title="Nutrition plans"
        can_upgrade={@can_upgrade?}
        owner_name={@current_scope.owner_name}
      >
        Meal plans with calories and macros for each client. Existing plans stay readable.
      </.closed_sign>
      
      <div id="plans" phx-update="stream">
        <div
          id="plans-empty"
          class="hidden border-b border-line/40 px-4 py-6 text-ink-2 only:block sm:px-[26px]"
        >
          No nutrition plans yet.
        </div>
        
        <.sign
          :for={{id, plan} <- @streams.plans}
          id={id}
          icon={:nutrition}
          time={Calendar.strftime(plan.start_date, "%-d %b")}
          time_label="Starts"
        >
          <:title>{plan.name}</:title>
           {plan_detail(plan)}
          <:actions>
            <.sign_action navigate={~p"/trainer/nutrition/#{plan.id}"}>Open</.sign_action>
          </:actions>
        </.sign>
      </div>
    </.sign_group>
    """
  end

  defp plan_detail(plan) do
    [plan.daily_calories && "#{plan.daily_calories} kcal", plan.is_template && "Template"]
    |> Enum.filter(& &1)
    |> Enum.join(" · ")
  end

  defp nutrition_form(assigns) do
    ~H"""
    <.page_header>
      {if @live_action == :new, do: "New nutrition plan", else: "Edit nutrition plan"}
      <:subtitle>
        {if @live_action == :new, do: "Calories, dates and who it is for.", else: @nutrition_plan.name}
      </:subtitle>
    </.page_header>

    <.form
      for={@form}
      id="nutrition-form"
      phx-submit={if @live_action == :new, do: "save", else: "update"}
      phx-change="validate"
      class="max-w-2xl px-4 py-6 sm:px-[26px]"
    >
      <.input field={@form[:name]} type="text" label="Plan name" required />
      <.input field={@form[:description]} type="textarea" label="Description" />
      <div class="grid gap-x-6 sm:grid-cols-2">
        <.input field={@form[:daily_calories]} type="number" label="Daily calories" min="0" />
        <.input
          field={@form[:client_id]}
          type="select"
          label="Client"
          prompt="Choose a client"
          options={Enum.map(@clients, &{"#{&1.first_name} #{&1.last_name}", &1.id})}
          required
        /> <.input field={@form[:start_date]} type="date" label="Start date" required />
        <.input field={@form[:end_date]} type="date" label="End date" />
      </div>
       <.input field={@form[:is_template]} type="checkbox" label="Save as a template" />
      <div class="mt-6 flex flex-wrap gap-3">
        <.button type="submit" variant="primary">
          {if @live_action == :new, do: "Create plan", else: "Save"}
        </.button>
        <.button navigate={
          if @live_action == :new,
            do: ~p"/trainer/nutrition",
            else: ~p"/trainer/nutrition/#{@nutrition_plan.id}"
        }>
          Cancel
        </.button>
      </div>
    </.form>
    """
  end

  defp nutrition_show(assigns) do
    ~H"""
    <.page_header>
      {@nutrition_plan.name}
      <:subtitle>{@nutrition_plan.description || "No description."}</:subtitle>
      
      <:actions>
        <.sign_action
          :if={@can_update?}
          id="edit-plan"
          navigate={~p"/trainer/nutrition/#{@nutrition_plan.id}/edit"}
        >
          Edit
        </.sign_action>
      </:actions>
    </.page_header>

    <.sign_group label="Details">
      <div class="px-4 sm:px-[26px]">
        <.list>
          <:item title="Client">
            {@nutrition_plan.client &&
              "#{@nutrition_plan.client.first_name} #{@nutrition_plan.client.last_name}"}
          </:item>
          
          <:item title="Daily calories">{@nutrition_plan.daily_calories || "Not set"}</:item>
          
          <:item title="Dates">
            {Calendar.strftime(@nutrition_plan.start_date, "%-d %b %Y")}{if @nutrition_plan.end_date,
              do: " to #{Calendar.strftime(@nutrition_plan.end_date, "%-d %b %Y")}"}
          </:item>
          
          <:item title="Template">{if @nutrition_plan.is_template, do: "Yes", else: "No"}</:item>
        </.list>
      </div>
    </.sign_group>

    <.sign_group :if={@can_delete?} label="Delete">
      <.sign :if={!@confirm_delete?} id="delete-plan" icon={:alert} draw={false}>
        <:title>Delete this plan</:title>
        The client keeps their history.
        <:actions>
          <.sign_action id="ask-delete" phx-click="ask_delete">Delete</.sign_action>
        </:actions>
      </.sign>
      
      <.sign :if={@confirm_delete?} id="delete-confirm" icon={:alert} state={:next} draw={false}>
        <:title>Delete {@nutrition_plan.name}?</:title>
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
  def handle_event("validate", %{"nutrition_plan" => params}, socket) do
    changeset =
      case socket.assigns.live_action do
        :new -> NutritionPlan.changeset(%NutritionPlan{}, own(params, socket))
        :edit -> NutritionPlan.update_changeset(socket.assigns.nutrition_plan, params)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: "nutrition_plan"))}
  end

  def handle_event("save", %{"nutrition_plan" => params}, socket) do
    scope = socket.assigns.current_scope

    with :ok <- Authorization.authorize(scope, :create, :nutrition_plan),
         :ok <- check_client(scope, params["client_id"]),
         {:ok, plan} <- Nutrition.create_nutrition_plan(own(params, socket)) do
      {:noreply,
       socket
       |> put_flash(:info, "Plan created.")
       |> push_navigate(to: ~p"/trainer/nutrition/#{plan.id}")}
    else
      {:client_error, message} ->
        {:noreply, client_error(socket, params, message)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "nutrition_plan"))}

      _blocked ->
        {:noreply, push_navigate(socket, to: ~p"/trainer/nutrition")}
    end
  end

  def handle_event("update", %{"nutrition_plan" => params}, socket) do
    scope = socket.assigns.current_scope
    plan = socket.assigns.nutrition_plan

    with :ok <- Authorization.authorize(scope, :update, plan),
         :ok <- check_client(scope, params["client_id"]),
         {:ok, plan} <- Nutrition.update_nutrition_plan(plan, params) do
      {:noreply,
       socket
       |> put_flash(:info, "Saved.")
       |> push_navigate(to: ~p"/trainer/nutrition/#{plan.id}")}
    else
      {:client_error, message} ->
        {:noreply, client_error(socket, params, message)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "nutrition_plan"))}

      _blocked ->
        {:noreply, put_flash(socket, :error, "Paused until payment clears.")}
    end
  end

  def handle_event("ask_delete", _params, socket),
    do: {:noreply, assign(socket, :confirm_delete?, true)}

  def handle_event("keep", _params, socket),
    do: {:noreply, assign(socket, :confirm_delete?, false)}

  def handle_event("delete", _params, socket) do
    plan = socket.assigns.nutrition_plan

    with :ok <- Authorization.authorize(socket.assigns.current_scope, :delete, plan),
         {:ok, _plan} <- Nutrition.delete_nutrition_plan(plan) do
      {:noreply,
       socket |> put_flash(:info, "Plan deleted.") |> push_navigate(to: ~p"/trainer/nutrition")}
    else
      _blocked ->
        {:noreply,
         socket
         |> assign(:confirm_delete?, false)
         |> put_flash(:error, "Paused until payment clears.")}
    end
  end

  # A plan can only be assigned to a client the requester coaches.
  defp check_client(_scope, client_id) when client_id in [nil, ""], do: :ok

  defp check_client(%Scope{} = scope, client_id) do
    if Scope.manages_client?(scope, client_id),
      do: :ok,
      else: {:client_error, "is not one of your clients"}
  end

  defp client_error(socket, params, message) do
    changeset =
      socket
      |> base_changeset(params)
      |> Ecto.Changeset.add_error(:client_id, message)
      |> Map.put(:action, :validate)

    assign(socket, :form, to_form(changeset, as: "nutrition_plan"))
  end

  defp base_changeset(%{assigns: %{live_action: :new}} = socket, params),
    do: NutritionPlan.changeset(%NutritionPlan{}, own(params, socket))

  defp base_changeset(socket, params),
    do: NutritionPlan.update_changeset(socket.assigns.nutrition_plan, params)

  defp own(params, socket) do
    user = socket.assigns.current_scope.user

    params
    |> Map.put("organization_id", user.organization_id)
    |> Map.put("trainer_id", user.id)
  end
end
