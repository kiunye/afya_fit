defmodule AfyaFitWeb.TrainerLive.Progress do
  use AfyaFitWeb, :live_view

  alias AfyaFit.{Clients, Tracking}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    if user.role != "trainer" do
      {:ok,
       socket
       |> put_flash(:error, "Access denied. Trainer role required.")
       |> redirect(to: ~p"/")}
    else
      {:ok,
       socket
       |> assign(:clients, [])
       |> assign(:progress_entries, [])
       |> assign(:client, nil)
       |> assign(:form, nil)
       |> assign(:analytics, %{})
       |> assign(:page_title, "Progress Tracking")}
    end
  end

  def handle_params(params, _uri, socket) do
    user = socket.assigns.current_scope.user

    case socket.assigns.live_action do
      :index ->
        clients =
          Clients.list_trainer_clients(user.id, %{status: "active"}) |> Enum.map(& &1.client)

        {:noreply, assign(socket, :clients, clients)}

      :client ->
        client = Clients.get_client!(user, params["client_id"])
        progress_entries = Tracking.list_progress_entries(client.id)
        analytics = calculate_analytics(progress_entries)

        {:noreply,
         socket
         |> assign(:client, client)
         |> assign(:progress_entries, progress_entries)
         |> assign(:analytics, analytics)}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%= case @live_action do %>
          <% :index -> %>
            <.progress_index
              clients={@clients}
              current_scope={@current_scope}
              live_action={@live_action}
            />
          <% :client -> %>
            <.progress_client
              client={@client}
              progress_entries={@progress_entries}
              analytics={@analytics}
              current_scope={@current_scope}
              live_action={@live_action}
            />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  attr :clients, :list, default: []
  attr :current_scope, :map, required: true
  attr :live_action, :atom, required: true

  def progress_index(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Progress Tracking</h1>
        <p class="mt-2 text-gray-600 dark:text-gray-400">
          View and manage client progress entries
        </p>
      </div>

      <%= if Enum.empty?(@clients) do %>
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-12 text-center">
          <.icon name="hero-chart-bar" class="w-16 h-16 mx-auto text-gray-400 mb-4" />
          <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-2">No clients yet</h3>
          <p class="text-gray-500 dark:text-gray-400">
            Add clients to start tracking their progress
          </p>
        </div>
      <% else %>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <%= for client <- @clients do %>
            <.link
              navigate={~p"/trainer/progress/#{client.id}"}
              class="bg-white dark:bg-gray-800 rounded-lg shadow p-6 hover:shadow-lg transition-shadow"
            >
              <div class="flex items-center mb-4">
                <div class="flex-shrink-0 h-12 w-12 rounded-full bg-gray-300 dark:bg-gray-600 flex items-center justify-center">
                  <span class="text-gray-600 dark:text-gray-300 font-medium text-lg">
                    {String.first(client.first_name || "")}
                  </span>
                </div>
                <div class="ml-4">
                  <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
                    {client.first_name} {client.last_name}
                  </h3>
                  <p class="text-sm text-gray-500 dark:text-gray-400">{client.email}</p>
                </div>
              </div>
              <div class="text-sm text-blue-600 dark:text-blue-400">
                View Progress →
              </div>
            </.link>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :client, :any, required: true
  attr :progress_entries, :list, default: []
  attr :analytics, :map, default: %{}
  attr :current_scope, :map, required: true
  attr :live_action, :atom, required: true

  def progress_client(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <.link
          navigate={~p"/trainer/progress"}
          class="text-blue-600 hover:text-blue-800 dark:text-blue-400 mb-4 inline-flex items-center"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Back to Progress
        </.link>
        <div class="flex justify-between items-center">
          <div>
            <h1 class="text-3xl font-bold text-gray-900 dark:text-white">
              {@client.first_name} {@client.last_name} - Progress
            </h1>
            <p class="mt-2 text-gray-600 dark:text-gray-400">{@client.email}</p>
          </div>
        </div>
      </div>

    <!-- Analytics Summary -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
          <div class="flex items-center">
            <div class="flex-shrink-0 bg-blue-500 rounded-lg p-3">
              <.icon name="hero-chart-bar" class="w-6 h-6 text-white" />
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Total Entries</p>
              <p class="text-2xl font-semibold text-gray-900 dark:text-white">
                {@analytics.total_entries}
              </p>
            </div>
          </div>
        </div>

        <%= if @analytics.weight_change do %>
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0 bg-green-500 rounded-lg p-3">
                <.icon name="hero-arrow-trending-down" class="w-6 h-6 text-white" />
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Weight Change</p>
                <p class="text-2xl font-semibold text-gray-900 dark:text-white">
                  {format_decimal(@analytics.weight_change)} kg
                </p>
              </div>
            </div>
          </div>
        <% end %>

        <%= if @analytics.body_fat_change do %>
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0 bg-purple-500 rounded-lg p-3">
                <.icon name="hero-chart-pie" class="w-6 h-6 text-white" />
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-500 dark:text-gray-400">
                  Body Fat Change
                </p>
                <p class="text-2xl font-semibold text-gray-900 dark:text-white">
                  {format_decimal(@analytics.body_fat_change)}%
                </p>
              </div>
            </div>
          </div>
        <% end %>
      </div>

    <!-- Progress Entries List -->
      <div class="bg-white dark:bg-gray-800 rounded-lg shadow">
        <div class="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
          <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Progress Entries</h2>
        </div>
        <%= if Enum.empty?(@progress_entries) do %>
          <div class="p-12 text-center">
            <p class="text-gray-500 dark:text-gray-400">No progress entries yet</p>
          </div>
        <% else %>
          <div class="divide-y divide-gray-200 dark:divide-gray-700">
            <%= for entry <- @progress_entries do %>
              <div class="p-6 hover:bg-gray-50 dark:hover:bg-gray-700">
                <div class="flex justify-between items-start">
                  <div>
                    <div class="flex items-center space-x-4">
                      <h3 class="text-lg font-medium text-gray-900 dark:text-white">
                        {Calendar.strftime(entry.entry_date, "%B %d, %Y")}
                      </h3>
                    </div>
                    <div class="mt-2 grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                      <%= if entry.weight do %>
                        <div>
                          <span class="text-gray-500 dark:text-gray-400">Weight:</span>
                          <span class="ml-2 font-medium text-gray-900 dark:text-white">
                            {format_decimal(entry.weight)} kg
                          </span>
                        </div>
                      <% end %>
                      <%= if entry.body_fat_percentage do %>
                        <div>
                          <span class="text-gray-500 dark:text-gray-400">Body Fat:</span>
                          <span class="ml-2 font-medium text-gray-900 dark:text-white">
                            {format_decimal(entry.body_fat_percentage)}%
                          </span>
                        </div>
                      <% end %>
                    </div>
                    <%= if entry.notes do %>
                      <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">{entry.notes}</p>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp calculate_analytics(entries) do
    sorted = Enum.sort_by(entries, & &1.entry_date, {:asc, Date})

    weight_change =
      case sorted do
        [] ->
          nil

        [first | _] = all ->
          last = List.last(all)
          if first.weight && last.weight, do: Decimal.sub(last.weight, first.weight), else: nil
      end

    body_fat_change =
      case sorted do
        [] ->
          nil

        [first | _] = all ->
          last = List.last(all)

          if first.body_fat_percentage && last.body_fat_percentage,
            do: Decimal.sub(last.body_fat_percentage, first.body_fat_percentage),
            else: nil
      end

    %{
      total_entries: length(entries),
      weight_change: weight_change,
      body_fat_change: body_fat_change
    }
  end

  defp format_decimal(%Decimal{} = decimal) do
    Decimal.to_float(decimal) |> :erlang.float_to_binary(decimals: 1)
  end

  defp format_decimal(value) when is_number(value) do
    :erlang.float_to_binary(value / 1, decimals: 1)
  end

  defp format_decimal(_), do: "—"
end
