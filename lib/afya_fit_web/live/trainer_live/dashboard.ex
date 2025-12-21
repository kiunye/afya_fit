defmodule AfyaFitWeb.TrainerLive.Dashboard do
  use AfyaFitWeb, :live_view

  alias AfyaFit.Dashboard

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    if user.role != "trainer" do
      {:ok,
       socket
       |> put_flash(:error, "Access denied. Trainer role required.")
       |> redirect(to: ~p"/")}
    else
      stats = Dashboard.get_trainer_stats(user)
      activity = Dashboard.get_recent_activity(user)

      {:ok,
       socket
       |> assign(:stats, stats)
       |> assign(:activity, activity)
       |> assign(:page_title, "Dashboard")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Dashboard</h1>
          <p class="mt-2 text-gray-600 dark:text-gray-400">
            Welcome back! Here's an overview of your fitness business.
          </p>
        </div>

        <!-- Stats Grid -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
          <.stat_card
            title="Active Clients"
            value={@stats.total_clients}
            icon="hero-users"
            color="blue"
          />
          <.stat_card
            title="Workout Plans"
            value={@stats.total_workout_plans}
            icon="hero-dumbbell"
            color="green"
          />
          <.stat_card
            title="Nutrition Plans"
            value={@stats.total_nutrition_plans}
            icon="hero-clipboard-document-list"
            color="purple"
          />
          <.stat_card
            title="Active Tasks"
            value={@stats.active_tasks}
            icon="hero-check-circle"
            color="orange"
          />
          <.stat_card
            title="Upcoming Events"
            value={@stats.upcoming_events}
            icon="hero-calendar"
            color="indigo"
          />
        </div>

        <!-- Quick Actions -->
        <div class="mb-8">
          <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">Quick Actions</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <.link
              navigate={~p"/trainer/clients/new"}
              class="flex items-center justify-center px-4 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
            >
              <.icon name="hero-user-plus" class="w-5 h-5 mr-2" />
              Add Client
            </.link>
            <.link
              navigate={~p"/trainer/workouts/new"}
              class="flex items-center justify-center px-4 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
            >
              <.icon name="hero-plus-circle" class="w-5 h-5 mr-2" />
              Create Workout Plan
            </.link>
            <.link
              navigate={~p"/trainer/nutrition/new"}
              class="flex items-center justify-center px-4 py-3 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
            >
              <.icon name="hero-clipboard-document-list" class="w-5 h-5 mr-2" />
              Create Nutrition Plan
            </.link>
            <.link
              navigate={~p"/trainer/clients"}
              class="flex items-center justify-center px-4 py-3 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors"
            >
              <.icon name="hero-users" class="w-5 h-5 mr-2" />
              View All Clients
            </.link>
          </div>
        </div>

        <!-- Recent Activity -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <!-- Recent Clients -->
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
              Recent Clients
            </h3>
            <div class="space-y-3">
              <%= if Enum.empty?(@activity.recent_clients) do %>
                <p class="text-gray-500 dark:text-gray-400 text-sm">No clients yet</p>
              <% else %>
                <%= for client <- @activity.recent_clients do %>
                  <div class="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-700 rounded">
                    <div>
                      <p class="font-medium text-gray-900 dark:text-white">
                        {client.first_name} {client.last_name}
                      </p>
                      <p class="text-sm text-gray-500 dark:text-gray-400">{client.email}</p>
                    </div>
                    <.link
                      navigate={~p"/trainer/clients/#{client.id}"}
                      class="text-blue-600 hover:text-blue-800 dark:text-blue-400"
                    >
                      View
                    </.link>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>

          <!-- Recent Workouts -->
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
              Recent Workout Plans
            </h3>
            <div class="space-y-3">
              <%= if Enum.empty?(@activity.recent_workouts) do %>
                <p class="text-gray-500 dark:text-gray-400 text-sm">No workout plans yet</p>
              <% else %>
                <%= for workout <- @activity.recent_workouts do %>
                  <div class="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-700 rounded">
                    <div>
                      <p class="font-medium text-gray-900 dark:text-white">{workout.name}</p>
                      <p class="text-sm text-gray-500 dark:text-gray-400">
                        {workout.duration_weeks} weeks • {workout.difficulty}
                      </p>
                    </div>
                    <.link
                      navigate={~p"/trainer/workouts/#{workout.id}"}
                      class="text-blue-600 hover:text-blue-800 dark:text-blue-400"
                    >
                      View
                    </.link>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :value, :integer, required: true
  attr :icon, :string, required: true
  attr :color, :string, default: "blue"

  defp stat_card(assigns) do
    color_classes = %{
      "blue" => "bg-blue-500",
      "green" => "bg-green-500",
      "purple" => "bg-purple-500",
      "orange" => "bg-orange-500",
      "indigo" => "bg-indigo-500"
    }

    assigns = assign(assigns, :icon_bg, Map.get(color_classes, assigns.color, "bg-blue-500"))

    ~H"""
    <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
      <div class="flex items-center">
        <div class={"flex-shrink-0 #{@icon_bg} rounded-lg p-3"}>
          <.icon name={@icon} class="w-6 h-6 text-white" />
        </div>
        <div class="ml-4">
          <p class="text-sm font-medium text-gray-500 dark:text-gray-400">{@title}</p>
          <p class="text-2xl font-semibold text-gray-900 dark:text-white">{@value}</p>
        </div>
      </div>
    </div>
    """
  end
end
