defmodule AfyaFitWeb.TrainerLive.Clients do
  use AfyaFitWeb, :live_view

  alias AfyaFit.Clients
  alias AfyaFit.Accounts.User

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    if user.role != "trainer" do
      {:ok,
       socket
       |> put_flash(:error, "Access denied. Trainer role required.")
       |> redirect(to: ~p"/")}
    else
      changeset = User.registration_changeset(%User{}, %{})
      form = to_form(changeset, as: "client")

      {:ok,
       socket
       |> assign(:clients, [])
       |> assign(:form, form)
       |> assign(:page_title, "Clients")}
    end
  end

  def handle_params(params, _uri, socket) do
    user = socket.assigns.current_scope.user

    case socket.assigns.live_action do
      :index ->
        clients = Clients.list_trainer_clients(user.id, %{}) |> Enum.map(& &1.client)
        {:noreply, assign(socket, :clients, clients)}

      :new ->
        changeset = User.registration_changeset(%User{}, %{})
        form = to_form(changeset, as: "client")
        {:noreply, assign(socket, :form, form)}

      :show ->
        client = Clients.get_client!(user, params["id"])
        {:noreply, assign(socket, :client, client)}

      :edit ->
        client = Clients.get_client!(user, params["id"])
        changeset = User.changeset(client, %{})
        form = to_form(changeset, as: "client")
        {:noreply, assign(socket, :client, client) |> assign(:form, form)}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%= case @live_action do %>
          <% :index -> %>
            <.clients_index
              clients={@clients}
              current_scope={@current_scope}
              live_action={@live_action}
            />
          <% :new -> %>
            <.clients_new
              form={@form}
              current_scope={@current_scope}
              live_action={@live_action}
            />
          <% :show -> %>
            <.clients_show
              client={@client}
              current_scope={@current_scope}
              live_action={@live_action}
            />
          <% :edit -> %>
            <.clients_edit
              form={@form}
              client={@client}
              current_scope={@current_scope}
              live_action={@live_action}
            />
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp clients_index(assigns) do
    ~H"""
    <div>
      <div class="flex justify-between items-center mb-6">
        <div>
          <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Clients</h1>
          <p class="mt-2 text-gray-600 dark:text-gray-400">
            Manage your clients and their fitness journeys
          </p>
        </div>
        <.link
          navigate={~p"/trainer/clients/new"}
          class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
        >
          <.icon name="hero-user-plus" class="w-5 h-5 inline mr-2" /> Add Client
        </.link>
      </div>

      <%= if Enum.empty?(@clients) do %>
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-12 text-center">
          <.icon name="hero-users" class="w-16 h-16 mx-auto text-gray-400 mb-4" />
          <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-2">No clients yet</h3>
          <p class="text-gray-500 dark:text-gray-400 mb-6">
            Get started by adding your first client
          </p>
          <.link
            navigate={~p"/trainer/clients/new"}
            class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            <.icon name="hero-user-plus" class="w-5 h-5 mr-2" /> Add Client
          </.link>
        </div>
      <% else %>
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
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
              <%= for client <- @clients do %>
                <tr class="hover:bg-gray-50 dark:hover:bg-gray-700">
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="flex items-center">
                      <div class="flex-shrink-0 h-10 w-10 rounded-full bg-gray-300 dark:bg-gray-600 flex items-center justify-center">
                        <span class="text-gray-600 dark:text-gray-300 font-medium">
                          {String.first(client.first_name || "")}
                        </span>
                      </div>
                      <div class="ml-4">
                        <div class="text-sm font-medium text-gray-900 dark:text-white">
                          {client.first_name} {client.last_name}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm text-gray-500 dark:text-gray-400">{client.email}</div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm text-gray-500 dark:text-gray-400">
                      {client.phone || "—"}
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <.link
                      navigate={~p"/trainer/clients/#{client.id}"}
                      class="text-blue-600 hover:text-blue-900 dark:text-blue-400 mr-4"
                    >
                      View
                    </.link>
                    <.link
                      navigate={~p"/trainer/clients/#{client.id}/edit"}
                      class="text-indigo-600 hover:text-indigo-900 dark:text-indigo-400"
                    >
                      Edit
                    </.link>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :current_scope, :map, required: true
  attr :live_action, :atom, required: true

  def clients_new(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <.link
          navigate={~p"/trainer/clients"}
          class="text-blue-600 hover:text-blue-800 dark:text-blue-400 mb-4 inline-flex items-center"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Back to Clients
        </.link>
        <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Add New Client</h1>
        <p class="mt-2 text-gray-600 dark:text-gray-400">
          Create a new client account in your organization
        </p>
      </div>

      <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <.form
          for={@form}
          id="client-form"
          phx-submit="save"
          phx-change="validate"
          class="space-y-6"
        >
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <.input
              field={@form[:first_name]}
              type="text"
              label="First Name"
              required
            />
            <.input
              field={@form[:last_name]}
              type="text"
              label="Last Name"
              required
            />
          </div>

          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            required
          />

          <.input
            field={@form[:password]}
            type="password"
            label="Password"
            required
          />

          <.input
            field={@form[:phone]}
            type="text"
            label="Phone"
          />

          <div class="flex justify-end space-x-4">
            <.link
              navigate={~p"/trainer/clients"}
              class="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700"
            >
              Cancel
            </.link>
            <.button
              type="submit"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
            >
              Create Client
            </.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp clients_show(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <.link
          navigate={~p"/trainer/clients"}
          class="text-blue-600 hover:text-blue-800 dark:text-blue-400 mb-4 inline-flex items-center"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Back to Clients
        </.link>
        <div class="flex justify-between items-center">
          <div>
            <h1 class="text-3xl font-bold text-gray-900 dark:text-white">
              {@client.first_name} {@client.last_name}
            </h1>
            <p class="mt-2 text-gray-600 dark:text-gray-400">{@client.email}</p>
          </div>
          <.link
            navigate={~p"/trainer/clients/#{@client.id}/edit"}
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            Edit Client
          </.link>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
          <h2 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
            Client Information
          </h2>
          <dl class="space-y-4">
            <div>
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Email</dt>
              <dd class="mt-1 text-sm text-gray-900 dark:text-white">{@client.email}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Phone</dt>
              <dd class="mt-1 text-sm text-gray-900 dark:text-white">
                {@client.phone || "Not provided"}
              </dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500 dark:text-gray-400">Timezone</dt>
              <dd class="mt-1 text-sm text-gray-900 dark:text-white">{@client.timezone}</dd>
            </div>
          </dl>
        </div>

        <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
          <h2 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">Quick Actions</h2>
          <div class="space-y-3">
            <.link
              navigate={~p"/trainer/progress/#{@client.id}"}
              class="block w-full px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 text-center"
            >
              View Progress
            </.link>
            <.link
              navigate={~p"/trainer/workouts"}
              class="block w-full px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 text-center"
            >
              Assign Workout
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :client, :any, required: true
  attr :current_scope, :map, required: true
  attr :live_action, :atom, required: true

  def clients_edit(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <.link
          navigate={~p"/trainer/clients/#{@client.id}"}
          class="text-blue-600 hover:text-blue-800 dark:text-blue-400 mb-4 inline-flex items-center"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Back to Client
        </.link>
        <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Edit Client</h1>
      </div>

      <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
        <.form
          for={@form}
          id="client-form"
          phx-submit="update"
          phx-change="validate"
          class="space-y-6"
        >
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <.input
              field={@form[:first_name]}
              type="text"
              label="First Name"
              required
            />
            <.input
              field={@form[:last_name]}
              type="text"
              label="Last Name"
              required
            />
          </div>

          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            required
          />

          <.input
            field={@form[:phone]}
            type="text"
            label="Phone"
          />

          <div class="flex justify-end space-x-4">
            <.link
              navigate={~p"/trainer/clients/#{@client.id}"}
              class="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700"
            >
              Cancel
            </.link>
            <.button
              type="submit"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
            >
              Update Client
            </.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  def handle_event("validate", %{"client" => client_params}, socket) do
    changeset =
      case socket.assigns.live_action do
        :new ->
          User.registration_changeset(%User{}, client_params)

        :edit ->
          User.changeset(socket.assigns.client, client_params)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: "client"))}
  end

  def handle_event("save", %{"client" => client_params}, socket) do
    user = socket.assigns.current_scope.user

    case Clients.create_client(user, client_params) do
      {:ok, _client} ->
        {:noreply,
         socket
         |> put_flash(:info, "Client created successfully")
         |> push_navigate(to: ~p"/trainer/clients")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "client"))}
    end
  end

  def handle_event("update", %{"client" => client_params}, socket) do
    case Clients.update_client(socket.assigns.client, client_params) do
      {:ok, _client} ->
        {:noreply,
         socket
         |> put_flash(:info, "Client updated successfully")
         |> push_navigate(to: ~p"/trainer/clients/#{socket.assigns.client.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "client"))}
    end
  end
end
