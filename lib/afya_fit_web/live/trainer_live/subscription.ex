defmodule AfyaFitWeb.TrainerLive.Subscription do
  use AfyaFitWeb, :live_view

  alias AfyaFit.{Billing, Organizations}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    if user.role != "trainer" do
      {:ok,
       socket
       |> put_flash(:error, "Access denied. Trainer role required.")
       |> redirect(to: ~p"/")}
    else
      organization = Organizations.get_organization!(user.organization_id)
      subscription = Billing.get_subscription_by_organization(organization.id)
      invoices = if subscription, do: Billing.list_invoices(subscription.id), else: []

      {:ok,
       socket
       |> assign(:organization, organization)
       |> assign(:subscription, subscription)
       |> assign(:invoices, invoices)
       |> assign(:page_title, "Subscription")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="mb-6">
          <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Subscription</h1>
          <p class="mt-2 text-gray-600 dark:text-gray-400">
            Manage your organization's subscription and billing
          </p>
        </div>

        <%= if @subscription do %>
          <!-- Current Subscription -->
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6 mb-6">
            <div class="flex justify-between items-start mb-4">
              <div>
                <h2 class="text-xl font-semibold text-gray-900 dark:text-white">
                  Current Plan
                </h2>
                <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
                  {format_plan_type(@subscription.plan_type)}
                </p>
              </div>
              <span class={[
                "px-3 py-1 rounded-full text-sm font-medium",
                status_color(@subscription.status)
              ]}>
                {String.capitalize(@subscription.status)}
              </span>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
              <div>
                <p class="text-sm text-gray-500 dark:text-gray-400">Current Period</p>
                <p class="text-lg font-medium text-gray-900 dark:text-white">
                  {Calendar.strftime(@subscription.current_period_start, "%B %d, %Y")} - {Calendar.strftime(
                    @subscription.current_period_end,
                    "%B %d, %Y"
                  )}
                </p>
              </div>
              <%= if @subscription.cancel_at_period_end do %>
                <div>
                  <p class="text-sm text-gray-500 dark:text-gray-400">Cancellation</p>
                  <p class="text-lg font-medium text-orange-600 dark:text-orange-400">
                    Cancels on {Calendar.strftime(@subscription.current_period_end, "%B %d, %Y")}
                  </p>
                </div>
              <% end %>
            </div>

            <%= if @subscription.status == "active" && !@subscription.cancel_at_period_end do %>
              <button
                phx-click="cancel_subscription"
                class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
              >
                Cancel Subscription
              </button>
            <% end %>
          </div>
          
    <!-- Invoices -->
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">Invoices</h2>
            <%= if Enum.empty?(@invoices) do %>
              <p class="text-gray-500 dark:text-gray-400">No invoices yet</p>
            <% else %>
              <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                  <thead class="bg-gray-50 dark:bg-gray-700">
                    <tr>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                        Invoice #
                      </th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                        Amount
                      </th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                        Status
                      </th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase">
                        Due Date
                      </th>
                    </tr>
                  </thead>
                  <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                    <%= for invoice <- @invoices do %>
                      <tr>
                        <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-white">
                          {invoice.invoice_number}
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                          {format_amount(invoice.amount)} {invoice.currency}
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                          <span class={[
                            "px-2 py-1 rounded-full text-xs font-medium",
                            invoice_status_color(invoice.status)
                          ]}>
                            {String.capitalize(invoice.status)}
                          </span>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                          {Calendar.strftime(invoice.due_date, "%B %d, %Y")}
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        <% else %>
          <!-- No Subscription -->
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-12 text-center">
            <.icon name="hero-credit-card" class="w-16 h-16 mx-auto text-gray-400 mb-4" />
            <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-2">
              No active subscription
            </h3>
            <p class="text-gray-500 dark:text-gray-400 mb-6">
              You're currently on the free plan. Upgrade to unlock premium features.
            </p>
            <button
              phx-click="upgrade"
              class="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
            >
              Upgrade to Pro
            </button>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("cancel_subscription", _params, socket) do
    case Billing.cancel_subscription(socket.assigns.subscription) do
      {:ok, subscription} ->
        {:noreply,
         socket
         |> assign(:subscription, subscription)
         |> put_flash(:info, "Subscription will be cancelled at the end of the current period")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to cancel subscription. Please try again.")}
    end
  end

  def handle_event("upgrade", _params, socket) do
    # TODO: Implement upgrade flow with payment initialization
    {:noreply,
     socket
     |> put_flash(:info, "Upgrade functionality coming soon. Please contact support.")}
  end

  defp format_plan_type("free"), do: "Free Plan"
  defp format_plan_type("pro"), do: "Pro Plan"
  defp format_plan_type("enterprise"), do: "Enterprise Plan"
  defp format_plan_type(_), do: "Unknown Plan"

  defp status_color("active"),
    do: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"

  defp status_color("cancelled"), do: "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"

  defp status_color("expired"),
    do: "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200"

  defp status_color("past_due"),
    do: "bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200"

  defp status_color(_), do: "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200"

  defp invoice_status_color("paid"),
    do: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"

  defp invoice_status_color("pending"),
    do: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200"

  defp invoice_status_color("failed"),
    do: "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"

  defp invoice_status_color(_),
    do: "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200"

  defp format_amount(%Decimal{} = amount) do
    Decimal.to_float(amount) |> :erlang.float_to_binary(decimals: 2)
  end

  defp format_amount(amount) when is_number(amount) do
    :erlang.float_to_binary(amount / 1, decimals: 2)
  end
end
