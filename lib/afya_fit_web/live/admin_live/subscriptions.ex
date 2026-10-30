defmodule AfyaFitWeb.AdminLive.Subscriptions do
  @moduledoc """
  Platform: every subscription, so a platform admin can see who is paying, who
  is past due and who is leaving. Organisations on the Free plan with no
  subscription are not listed here.
  """
  use AfyaFitWeb, :live_view

  import AfyaFitWeb.SignComponents

  alias AfyaFit.Platform
  alias AfyaFitWeb.Access

  @filters [
    {"All", nil},
    {"Active", "active"},
    {"Past due", "past_due"},
    {"Cancelling", "cancelling"},
    {"Cancelled", "cancelled"},
    {"Expired", "expired"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> Access.guard(:access, :admin_panel)
      |> assign(:page_title, "Subscriptions")
      |> assign(:filters, @filters)
      |> assign(:status, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    if socket.assigns.denied do
      {:noreply, socket}
    else
      status = if params["status"] in Platform.subscription_filters(), do: params["status"]
      rows = Platform.list_subscriptions(status)

      {:noreply,
       socket
       |> assign(:status, status)
       |> assign(:count, length(rows))
       |> assign(:income, Platform.monthly_income())
       |> assign(:by_plan, Enum.frequencies_by(rows, & &1.plan_type))
       |> assign(:empty?, rows == [])
       |> stream(:subscriptions, rows, reset: true)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:subscriptions}>
      <.denied_sign :if={@denied} kind={elem(@denied, 0)} message={elem(@denied, 1)} />
      <div :if={!@denied} id="subscriptions-page">
        <.page_header>
          Subscriptions
          <:subtitle>
            <b class="text-ink">
              {@count} {if @count == 1, do: "subscription", else: "subscriptions"}.
            </b> {plan_summary(@by_plan)} Expected each month: <b class="text-ink">{AfyaFit.Billing.Plans.format(@income)}</b>.
          </:subtitle>
        </.page_header>
        
        <.sign_group label="Subscriptions">
          <nav aria-label="Filter" class="flex flex-wrap gap-2 px-4 pb-3 sm:px-[26px]">
            <.link
              :for={{label, value} <- @filters}
              patch={
                if value, do: ~p"/admin/subscriptions?status=#{value}", else: ~p"/admin/subscriptions"
              }
              aria-current={@status == value && "true"}
              class={[
                "rounded-control border-2 px-3 py-1 text-xs font-bold uppercase tracking-[.06em]",
                @status == value && "border-white bg-white text-field-0",
                @status != value && "border-line/50 text-ink-2 hover:border-white hover:text-white"
              ]}
            >
              {label}
            </.link>
          </nav>
          
          <div id="subscriptions" phx-update="stream">
            <div id="subscriptions-empty" class="hidden px-4 py-6 text-ink-2 only:block sm:px-[26px]">
              No subscriptions here.
            </div>
            
            <.sign
              :for={{id, row} <- @streams.subscriptions}
              id={id}
              icon={:billing}
              draw={false}
              overdue={row.status in ["past_due", "expired"]}
              time={local(row.period_end, @current_scope, "%-d %b")}
              time_label="Period ends"
            >
              <:title>{row.organization}</:title>
               {String.capitalize(row.plan_type)} plan · {status_text(row)}
              <:actions>
                <.sign_action navigate={~p"/admin/organizations/#{row.organization_id}"}>
                  Open
                </.sign_action>
              </:actions>
            </.sign>
          </div>
        </.sign_group>
      </div>
    </Layouts.app>
    """
  end

  defp status_text(%{status: "cancelled", cancel_at_period_end: true}), do: "cancelling"
  defp status_text(%{status: status}), do: String.replace(status, "_", " ")

  defp plan_summary(by_plan) do
    ["free", "pro", "enterprise"]
    |> Enum.filter(&Map.has_key?(by_plan, &1))
    |> Enum.map_join(", ", &"#{by_plan[&1]} #{&1}")
  end
end
