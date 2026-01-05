defmodule AfyaFitWeb.AdminLive.Dashboard do
  use AfyaFitWeb, :live_view

  alias AfyaFit.{Accounts, Billing, Clients, Organizations}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    if user.role != "admin" do
      {:ok,
       socket
       |> put_flash(:error, "Access denied. Admin role required.")
       |> redirect(to: ~p"/")}
    else
      organization = Organizations.get_organization!(user.organization_id)
      trainers = Accounts.list_organization_users(user.organization_id, "trainer")
      clients = Clients.list_organization_clients(user.organization_id, %{})
      subscription = Billing.get_subscription_by_organization(user.organization_id)

      {:ok,
       socket
       |> assign(:organization, organization)
       |> assign(:trainers, trainers)
       |> assign(:clients, clients)
       |> assign(:subscription, subscription)
       |> assign(:page_title, "Admin Dashboard")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Admin Dashboard</h1>
          <p class="mt-2 text-gray-600 dark:text-gray-400">
            Manage your organization: trainers and clients.
          </p>
        </div>

        <!-- Stats -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <.stat_card
            title="Trainers"
            value={length(@trainers)}
            icon="hero-user-group"
            color="blue"
          />
          <.stat_card
            title="Clients"
            value={length(@clients)}
            icon="hero-users"
            color="green"
          />
          <.stat_card
            title="Subscription"
            value={if @subscription, do: String.capitalize(@subscription.plan_type), else: "None"}
            icon="hero-credit-card"
            color="purple"
          />
        </div>

        <!-- Trainers Section -->
        <div class="mb-8">
          <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">Trainers</h2>
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow overflow-hidden">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                    Name
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                    Email
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                    Phone
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                <%= if Enum.empty?(@trainers) do %>
                  <tr>
                    <td colspan="3" class="px-6 py-4 text-center text-gray-500 dark:text-gray-400">
                      No trainers yet
                    </td>
                  </tr>
                <% else %>
                  <%= for trainer <- @trainers do %>
                    <tr>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-white">
                        {trainer.first_name} {trainer.last_name}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                        {trainer.email}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                        {trainer.phone || "—"}
                      </td>
                    </tr>
                  <% end %>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Clients Section -->
        <div class="mb-8">
          <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">Clients</h2>
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow overflow-hidden">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                    Name
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                    Email
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                    Phone
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                <%= if Enum.empty?(@clients) do %>
                  <tr>
                    <td colspan="3" class="px-6 py-4 text-center text-gray-500 dark:text-gray-400">
                      No clients yet
                    </td>
                  </tr>
                <% else %>
                  <%= for client <- @clients do %>
                    <tr>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-white">
                        {client.first_name} {client.last_name}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                        {client.email}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                        {client.phone || "—"}
                      </td>
                    </tr>
                  <% end %>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true
  attr :color, :string, default: "blue"

  defp stat_card(assigns) do
    color_classes = %{
      "blue" => "bg-blue-500",
      "green" => "bg-green-500",
      "purple" => "bg-purple-500"
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
