defmodule AfyaFitWeb.TrainerLive.Workouts do
  use AfyaFitWeb, :live_view

  alias AfyaFit.Workouts
  alias AfyaFit.Workouts.WorkoutPlan

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    if user.role != "trainer" do
      {:ok,
       socket
       |> put_flash(:error, "Access denied. Trainer role required.")
       |> redirect(to: ~p"/")}
    else
      changeset = WorkoutPlan.changeset(%WorkoutPlan{}, %{})
      form = to_form(changeset, as: "workout_plan")

      {:ok,
       socket
       |> assign(:workout_plans, [])
       |> assign(:form, form)
       |> assign(:page_title, "Workout Plans")}
    end
  end

  def handle_params(params, _uri, socket) do
    user = socket.assigns.current_scope.user

    case socket.assigns.live_action do
      :index ->
        workout_plans =
          Workouts.list_workout_plans()
          |> Enum.filter(fn plan ->
            plan.organization_id == user.organization_id &&
              (plan.trainer_id == user.id || plan.is_public)
          end)
          |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

        {:noreply, assign(socket, :workout_plans, workout_plans)}

      :new ->
        changeset = WorkoutPlan.changeset(%WorkoutPlan{}, %{})
        form = to_form(changeset, as: "workout_plan")
        {:noreply, assign(socket, :form, form)}

      :show ->
        workout_plan = Workouts.get_workout_plan!(params["id"])
        {:noreply, assign(socket, :workout_plan, workout_plan)}

      :edit ->
        workout_plan = Workouts.get_workout_plan!(params["id"])
        changeset = WorkoutPlan.changeset(workout_plan, %{})
        form = to_form(changeset, as: "workout_plan")
        {:noreply, assign(socket, :workout_plan, workout_plan) |> assign(:form, form)}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%= case @live_action do %>
          <% :index -> %>
            <.workouts_index
              workout_plans={@workout_plans}
              current_scope={@current_scope}
              live_action={@live_action}
            />

          <% :new -> %>
            <.workouts_new
              form={@form}
              current_scope={@current_scope}
              live_action={@live_action}
            />

          <% :show -> %>
            <.workouts_show
              workout_plan={@workout_plan}
              current_scope={@current_scope}
              live_action={@live_action}
            />

          <% :edit -> %>
            <.workouts_edit
              form={@form}
              workout_plan={@workout_plan}
              current_scope={@current_scope}
              live_action={@live_action}
            />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :workout_plans, :list, default: []
  attr :current_scope, :map, required: true
  attr :live_action, :atom, required: true

  def workouts_index(assigns) do
    ~H"""
    <div>
      <div class="flex justify-between items-center mb-6">
        <div>
          <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Workout Plans</h1>
          <p class="mt-2 text-gray-600 dark:text-gray-400">
            Create and manage workout plans for your clients
          </p>
        </div>
        <.link
          navigate={~p"/trainer/workouts/new"}
          class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
        >
          <.icon name="hero-plus-circle" class="w-5 h-5 inline mr-2" />
          New Workout Plan
        </.link>
      </div>

      <%= if Enum.empty?(@workout_plans) do %>
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-12 text-center">
          <.icon name="hero-dumbbell" class="w-16 h-16 mx-auto text-gray-400 mb-4" />
          <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-2">
            No workout plans yet
          </h3>
          <p class="text-gray-500 dark:text-gray-400 mb-6">
            Create your first workout plan to get started
          </p>
          <.link
            navigate={~p"/trainer/workouts/new"}
            class="inline-flex items-center px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
          >
            <.icon name="hero-plus-circle" class="w-5 h-5 mr-2" />
            Create Workout Plan
          </.link>
        </div>
      <% else %>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <%= for plan <- @workout_plans do %>
            <div class="bg-white dark:bg-gray-800 rounded-lg shadow hover:shadow-lg transition-shadow">
              <div class="p-6">
                <div class="flex justify-between items-start mb-4">
                  <h3 class="text-xl font-semibold text-gray-900 dark:text-white">
                    {plan.name}
                  </h3>
                  <%= if plan.is_template do %>
                    <span class="px-2 py-1 text-xs font-medium bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200 rounded">
                      Template
                    </span>
                  <% end %>
                </div>
                <p class="text-gray-600 dark:text-gray-400 text-sm mb-4">
                  {plan.description || "No description"}
                </p>
                <div class="flex items-center text-sm text-gray-500 dark:text-gray-400 mb-4">
                  <span>{plan.duration_weeks} weeks</span>
                  <span class="mx-2">•</span>
                  <span class="capitalize">{plan.difficulty}</span>
                </div>
                <div class="flex space-x-2">
                  <.link
                    navigate={~p"/trainer/workouts/#{plan.id}"}
                    class="flex-1 px-3 py-2 bg-blue-600 text-white text-center rounded-lg hover:bg-blue-700 text-sm"
                  >
                    View
                  </.link>
                  <%= if plan.trainer_id == assigns.current_scope.user.id do %>
                    <.link
                      navigate={~p"/trainer/workouts/#{plan.id}/edit"}
                      class="flex-1 px-3 py-2 bg-gray-600 text-white text-center rounded-lg hover:bg-gray-700 text-sm"
                    >
                      Edit
                    </.link>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :current_scope, :map, required: true
  attr :live_action, :atom, required: true

  def workouts_new(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <.link
          navigate={~p"/trainer/workouts"}
          class="text-blue-600 hover:text-blue-800 dark:text-blue-400 mb-4 inline-flex items-center"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" />
          Back to Workout Plans
        </.link>
        <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Create Workout Plan</h1>
      </div>

      <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <.form
          for={@form}
          id="workout-plan-form"
          phx-submit="save"
          phx-change="validate"
          class="space-y-6"
        >
          <.input
            field={@form[:name]}
            type="text"
            label="Plan Name"
            required
          />

          <.input
            field={@form[:description]}
            type="textarea"
            label="Description"
            rows="4"
          />

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <.input
              field={@form[:duration_weeks]}
              type="number"
              label="Duration (weeks)"
              required
            />

            <.input
              field={@form[:difficulty]}
              type="select"
              label="Difficulty"
              options={[
                {"Beginner", "beginner"},
                {"Intermediate", "intermediate"},
                {"Advanced", "advanced"}
              ]}
              required
            />
          </div>

          <div class="flex items-center space-x-4">
            <.input
              field={@form[:is_template]}
              type="checkbox"
              label="Save as template"
            />
            <.input
              field={@form[:is_public]}
              type="checkbox"
              label="Make public (visible to all trainers in organization)"
            />
          </div>

          <div class="flex justify-end space-x-4">
            <.link
              navigate={~p"/trainer/workouts"}
              class="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700"
            >
              Cancel
            </.link>
            <.button
              type="submit"
              class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
            >
              Create Plan
            </.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :workout_plan, :any, required: true
  attr :current_scope, :map, required: true
  attr :live_action, :atom, required: true

  def workouts_show(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <.link
          navigate={~p"/trainer/workouts"}
          class="text-blue-600 hover:text-blue-800 dark:text-blue-400 mb-4 inline-flex items-center"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" />
          Back to Workout Plans
        </.link>
        <div class="flex justify-between items-center">
          <div>
            <h1 class="text-3xl font-bold text-gray-900 dark:text-white">{@workout_plan.name}</h1>
            <p class="mt-2 text-gray-600 dark:text-gray-400">
              {@workout_plan.description || "No description"}
            </p>
          </div>
          <%= if @workout_plan.trainer_id == assigns.current_scope.user.id do %>
            <.link
              navigate={~p"/trainer/workouts/#{@workout_plan.id}/edit"}
              class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
            >
              Edit Plan
            </.link>
          <% end %>
        </div>
      </div>

      <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <dl class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Duration</dt>
            <dd class="mt-1 text-sm text-gray-900 dark:text-white">
              {@workout_plan.duration_weeks} weeks
            </dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Difficulty</dt>
            <dd class="mt-1 text-sm text-gray-900 dark:text-white capitalize">
              {@workout_plan.difficulty}
            </dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Template</dt>
            <dd class="mt-1 text-sm text-gray-900 dark:text-white">
              {if @workout_plan.is_template, do: "Yes", else: "No"}
            </dd>
          </div>
          <div>
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Public</dt>
            <dd class="mt-1 text-sm text-gray-900 dark:text-white">
              {if @workout_plan.is_public, do: "Yes", else: "No"}
            </dd>
          </div>
        </dl>
      </div>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :workout_plan, :any, required: true
  attr :current_scope, :map, required: true
  attr :live_action, :atom, required: true

  def workouts_edit(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <.link
          navigate={~p"/trainer/workouts/#{@workout_plan.id}"}
          class="text-blue-600 hover:text-blue-800 dark:text-blue-400 mb-4 inline-flex items-center"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" />
          Back to Workout Plan
        </.link>
        <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Edit Workout Plan</h1>
      </div>

      <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <.form
          for={@form}
          id="workout-plan-form"
          phx-submit="update"
          phx-change="validate"
          class="space-y-6"
        >
          <.input
            field={@form[:name]}
            type="text"
            label="Plan Name"
            required
          />

          <.input
            field={@form[:description]}
            type="textarea"
            label="Description"
            rows="4"
          />

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <.input
              field={@form[:duration_weeks]}
              type="number"
              label="Duration (weeks)"
              required
            />

            <.input
              field={@form[:difficulty]}
              type="select"
              label="Difficulty"
              options={[
                {"Beginner", "beginner"},
                {"Intermediate", "intermediate"},
                {"Advanced", "advanced"}
              ]}
              required
            />
          </div>

          <div class="flex items-center space-x-4">
            <.input
              field={@form[:is_template]}
              type="checkbox"
              label="Save as template"
            />
            <.input
              field={@form[:is_public]}
              type="checkbox"
              label="Make public"
            />
          </div>

          <div class="flex justify-end space-x-4">
            <.link
              navigate={~p"/trainer/workouts/#{@workout_plan.id}"}
              class="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700"
            >
              Cancel
            </.link>
            <.button
              type="submit"
              class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
            >
              Update Plan
            </.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  def handle_event("validate", %{"workout_plan" => plan_params}, socket) do
    user = socket.assigns.current_scope.user

    attrs =
      plan_params
      |> Map.put("organization_id", user.organization_id)
      |> Map.put("trainer_id", user.id)

    changeset =
      case socket.assigns.live_action do
        :new ->
          WorkoutPlan.changeset(%WorkoutPlan{}, attrs)

        :edit ->
          WorkoutPlan.changeset(socket.assigns.workout_plan, attrs)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: "workout_plan"))}
  end

  def handle_event("save", %{"workout_plan" => plan_params}, socket) do
    user = socket.assigns.current_scope.user

    attrs =
      plan_params
      |> Map.put("organization_id", user.organization_id)
      |> Map.put("trainer_id", user.id)

    case Workouts.create_workout_plan(attrs) do
      {:ok, workout_plan} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workout plan created successfully")
         |> push_navigate(to: ~p"/trainer/workouts/#{workout_plan.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "workout_plan"))}
    end
  end

  def handle_event("update", %{"workout_plan" => plan_params}, socket) do
    case Workouts.update_workout_plan(socket.assigns.workout_plan, plan_params) do
      {:ok, workout_plan} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workout plan updated successfully")
         |> push_navigate(to: ~p"/trainer/workouts/#{workout_plan.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "workout_plan"))}
    end
  end
end
