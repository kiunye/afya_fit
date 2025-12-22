defmodule AfyaFitWeb.TrainerLive.Nutrition do
  use AfyaFitWeb, :live_view

  alias AfyaFit.{Clients, Nutrition}
  alias AfyaFit.Nutrition.NutritionPlan

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    if user.role != "trainer" do
      {:ok,
       socket
       |> put_flash(:error, "Access denied. Trainer role required.")
       |> redirect(to: ~p"/")}
    else
      changeset = NutritionPlan.changeset(%NutritionPlan{}, %{})
      form = to_form(changeset, as: "nutrition_plan")

      {:ok,
       socket
       |> assign(:nutrition_plans, [])
       |> assign(:clients, [])
       |> assign(:form, form)
       |> assign(:page_title, "Nutrition Plans")}
    end
  end

  def handle_params(params, _uri, socket) do
    user = socket.assigns.current_scope.user

    case socket.assigns.live_action do
      :index ->
        nutrition_plans =
          Nutrition.list_nutrition_plans()
          |> Enum.filter(fn plan ->
            plan.organization_id == user.organization_id &&
              plan.trainer_id == user.id
          end)
          |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

        clients =
          Clients.list_trainer_clients(user.id, %{status: "active"}) |> Enum.map(& &1.client)

        {:noreply,
         socket
         |> assign(:nutrition_plans, nutrition_plans)
         |> assign(:clients, clients)}

      :new ->
        clients =
          Clients.list_trainer_clients(user.id, %{status: "active"}) |> Enum.map(& &1.client)

        changeset = NutritionPlan.changeset(%NutritionPlan{}, %{})
        form = to_form(changeset, as: "nutrition_plan")
        {:noreply, assign(socket, :form, form) |> assign(:clients, clients)}

      :show ->
        nutrition_plan = Nutrition.get_nutrition_plan!(params["id"])
        {:noreply, assign(socket, :nutrition_plan, nutrition_plan)}

      :edit ->
        clients =
          Clients.list_trainer_clients(user.id, %{status: "active"}) |> Enum.map(& &1.client)

        nutrition_plan = Nutrition.get_nutrition_plan!(params["id"])
        changeset = NutritionPlan.changeset(nutrition_plan, %{})
        form = to_form(changeset, as: "nutrition_plan")

        {:noreply,
         socket
         |> assign(:nutrition_plan, nutrition_plan)
         |> assign(:form, form)
         |> assign(:clients, clients)}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%= case @live_action do %>
          <% :index -> %>
            <.nutrition_index
              nutrition_plans={@nutrition_plans}
              current_scope={@current_scope}
              live_action={@live_action}
            />
          <% :new -> %>
            <.nutrition_new
              form={@form}
              clients={@clients}
              current_scope={@current_scope}
              live_action={@live_action}
            />
          <% :show -> %>
            <.nutrition_show
              nutrition_plan={@nutrition_plan}
              current_scope={@current_scope}
              live_action={@live_action}
            />
          <% :edit -> %>
            <.nutrition_edit
              form={@form}
              nutrition_plan={@nutrition_plan}
              clients={@clients}
              current_scope={@current_scope}
              live_action={@live_action}
            />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :nutrition_plans, :list, default: []
  attr :current_scope, :map, required: true
  attr :live_action, :atom, required: true

  def nutrition_index(assigns) do
    ~H"""
    <div>
      <div class="flex justify-between items-center mb-6">
        <div>
          <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Nutrition Plans</h1>
          <p class="mt-2 text-gray-600 dark:text-gray-400">
            Create and manage nutrition plans for your clients
          </p>
        </div>
        <.link
          navigate={~p"/trainer/nutrition/new"}
          class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
        >
          <.icon name="hero-plus-circle" class="w-5 h-5 inline mr-2" /> New Nutrition Plan
        </.link>
      </div>

      <%= if Enum.empty?(@nutrition_plans) do %>
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-12 text-center">
          <.icon name="hero-clipboard-document-list" class="w-16 h-16 mx-auto text-gray-400 mb-4" />
          <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-2">
            No nutrition plans yet
          </h3>
          <p class="text-gray-500 dark:text-gray-400 mb-6">
            Create your first nutrition plan to get started
          </p>
          <.link
            navigate={~p"/trainer/nutrition/new"}
            class="inline-flex items-center px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
          >
            <.icon name="hero-plus-circle" class="w-5 h-5 mr-2" /> Create Nutrition Plan
          </.link>
        </div>
      <% else %>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <%= for plan <- @nutrition_plans do %>
            <div class="bg-white dark:bg-gray-800 rounded-lg shadow hover:shadow-lg transition-shadow">
              <div class="p-6">
                <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-2">
                  {plan.name}
                </h3>
                <p class="text-gray-600 dark:text-gray-400 text-sm mb-4">
                  {plan.description || "No description"}
                </p>
                <div class="space-y-2 text-sm text-gray-500 dark:text-gray-400 mb-4">
                  <div class="flex justify-between">
                    <span>Daily Calories:</span>
                    <span class="font-medium">{plan.daily_calories || "—"}</span>
                  </div>
                  <%= if plan.start_date && plan.end_date do %>
                    <div class="flex justify-between">
                      <span>Duration:</span>
                      <span class="font-medium">
                        {Calendar.strftime(plan.start_date, "%b %d")} - {Calendar.strftime(
                          plan.end_date,
                          "%b %d"
                        )}
                      </span>
                    </div>
                  <% end %>
                </div>
                <div class="flex space-x-2">
                  <.link
                    navigate={~p"/trainer/nutrition/#{plan.id}"}
                    class="flex-1 px-3 py-2 bg-purple-600 text-white text-center rounded-lg hover:bg-purple-700 text-sm"
                  >
                    View
                  </.link>
                  <.link
                    navigate={~p"/trainer/nutrition/#{plan.id}/edit"}
                    class="flex-1 px-3 py-2 bg-gray-600 text-white text-center rounded-lg hover:bg-gray-700 text-sm"
                  >
                    Edit
                  </.link>
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
  attr :clients, :list, default: []
  attr :current_scope, :map, required: true
  attr :live_action, :atom, required: true

  def nutrition_new(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <.link
          navigate={~p"/trainer/nutrition"}
          class="text-blue-600 hover:text-blue-800 dark:text-blue-400 mb-4 inline-flex items-center"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Back to Nutrition Plans
        </.link>
        <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Create Nutrition Plan</h1>
      </div>

      <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <.form
          for={@form}
          id="nutrition-plan-form"
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
              field={@form[:daily_calories]}
              type="number"
              label="Daily Calories"
            />

            <.input
              field={@form[:client_id]}
              type="select"
              label="Client (optional)"
              options={[
                {"Select a client...", ""}
                | Enum.map(@clients, fn client ->
                    {"#{client.first_name} #{client.last_name}", client.id}
                  end)
              ]}
            />
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <.input
              field={@form[:start_date]}
              type="date"
              label="Start Date"
            />

            <.input
              field={@form[:end_date]}
              type="date"
              label="End Date"
            />
          </div>

          <.input
            field={@form[:is_template]}
            type="checkbox"
            label="Save as template"
          />

          <div class="flex justify-end space-x-4">
            <.link
              navigate={~p"/trainer/nutrition"}
              class="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700"
            >
              Cancel
            </.link>
            <.button
              type="submit"
              class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
            >
              Create Plan
            </.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp nutrition_show(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <.link
          navigate={~p"/trainer/nutrition"}
          class="text-blue-600 hover:text-blue-800 dark:text-blue-400 mb-4 inline-flex items-center"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Back to Nutrition Plans
        </.link>
        <div class="flex justify-between items-center">
          <div>
            <h1 class="text-3xl font-bold text-gray-900 dark:text-white">
              {@nutrition_plan.name}
            </h1>
            <p class="mt-2 text-gray-600 dark:text-gray-400">
              {@nutrition_plan.description || "No description"}
            </p>
          </div>
          <.link
            navigate={~p"/trainer/nutrition/#{@nutrition_plan.id}/edit"}
            class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
          >
            Edit Plan
          </.link>
        </div>
      </div>

      <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <dl class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Daily Calories</dt>
            <dd class="mt-1 text-sm text-gray-900 dark:text-white">
              {@nutrition_plan.daily_calories || "Not set"}
            </dd>
          </div>
          <%= if @nutrition_plan.start_date do %>
            <div>
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Start Date</dt>
              <dd class="mt-1 text-sm text-gray-900 dark:text-white">
                {Calendar.strftime(@nutrition_plan.start_date, "%B %d, %Y")}
              </dd>
            </div>
          <% end %>
          <%= if @nutrition_plan.end_date do %>
            <div>
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">End Date</dt>
              <dd class="mt-1 text-sm text-gray-900 dark:text-white">
                {Calendar.strftime(@nutrition_plan.end_date, "%B %d, %Y")}
              </dd>
            </div>
          <% end %>
          <div>
            <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Template</dt>
            <dd class="mt-1 text-sm text-gray-900 dark:text-white">
              {if @nutrition_plan.is_template, do: "Yes", else: "No"}
            </dd>
          </div>
        </dl>
      </div>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :nutrition_plan, :any, required: true
  attr :clients, :list, default: []
  attr :current_scope, :map, required: true
  attr :live_action, :atom, required: true

  def nutrition_edit(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <.link
          navigate={~p"/trainer/nutrition/#{@nutrition_plan.id}"}
          class="text-blue-600 hover:text-blue-800 dark:text-blue-400 mb-4 inline-flex items-center"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Back to Nutrition Plan
        </.link>
        <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Edit Nutrition Plan</h1>
      </div>

      <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <.form
          for={@form}
          id="nutrition-plan-form"
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
              field={@form[:daily_calories]}
              type="number"
              label="Daily Calories"
            />

            <.input
              field={@form[:client_id]}
              type="select"
              label="Client (optional)"
              options={[
                {"Select a client...", ""}
                | Enum.map(@clients, fn client ->
                    {"#{client.first_name} #{client.last_name}", client.id}
                  end)
              ]}
            />
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <.input
              field={@form[:start_date]}
              type="date"
              label="Start Date"
            />

            <.input
              field={@form[:end_date]}
              type="date"
              label="End Date"
            />
          </div>

          <.input
            field={@form[:is_template]}
            type="checkbox"
            label="Save as template"
          />

          <div class="flex justify-end space-x-4">
            <.link
              navigate={~p"/trainer/nutrition/#{@nutrition_plan.id}"}
              class="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700"
            >
              Cancel
            </.link>
            <.button
              type="submit"
              class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
            >
              Update Plan
            </.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  def handle_event("validate", %{"nutrition_plan" => plan_params}, socket) do
    user = socket.assigns.current_scope.user

    attrs =
      plan_params
      |> Map.put("organization_id", user.organization_id)
      |> Map.put("trainer_id", user.id)

    changeset =
      case socket.assigns.live_action do
        :new ->
          NutritionPlan.changeset(%NutritionPlan{}, attrs)

        :edit ->
          NutritionPlan.changeset(socket.assigns.nutrition_plan, attrs)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: "nutrition_plan"))}
  end

  def handle_event("save", %{"nutrition_plan" => plan_params}, socket) do
    user = socket.assigns.current_scope.user

    attrs =
      plan_params
      |> Map.put("organization_id", user.organization_id)
      |> Map.put("trainer_id", user.id)

    case Nutrition.create_nutrition_plan(attrs) do
      {:ok, nutrition_plan} ->
        {:noreply,
         socket
         |> put_flash(:info, "Nutrition plan created successfully")
         |> push_navigate(to: ~p"/trainer/nutrition/#{nutrition_plan.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "nutrition_plan"))}
    end
  end

  def handle_event("update", %{"nutrition_plan" => plan_params}, socket) do
    case Nutrition.update_nutrition_plan(socket.assigns.nutrition_plan, plan_params) do
      {:ok, nutrition_plan} ->
        {:noreply,
         socket
         |> put_flash(:info, "Nutrition plan updated successfully")
         |> push_navigate(to: ~p"/trainer/nutrition/#{nutrition_plan.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "nutrition_plan"))}
    end
  end
end
