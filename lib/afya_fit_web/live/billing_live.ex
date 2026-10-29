defmodule AfyaFitWeb.BillingLive do
  @moduledoc """
  Billing: the organization's plan, its status and invoices. Organization
  admins manage it; platform admins can read it.
  """
  use AfyaFitWeb, :live_view

  import AfyaFitWeb.SignComponents

  alias AfyaFit.{Authorization, Billing}
  alias AfyaFitWeb.Access

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> Access.guard(:read, :subscription)
      |> assign(:page_title, "Billing")
      |> assign(:confirm_cancel?, false)

    if socket.assigns.denied do
      {:ok, socket}
    else
      {:ok, load(socket)}
    end
  end

  defp load(socket) do
    scope = socket.assigns.current_scope
    subscription = Billing.get_subscription_by_organization(scope.user.organization_id)
    invoices = if subscription, do: Billing.list_invoices(subscription.id), else: []

    socket
    |> assign(:subscription, subscription)
    |> assign(:can_manage?, Authorization.can?(scope, :manage, :subscription))
    |> assign(:invoices_empty?, invoices == [])
    |> stream(:invoices, invoices, reset: true)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:billing}>
      <.denied_sign :if={@denied} kind={elem(@denied, 0)} message={elem(@denied, 1)} />

      <div :if={!@denied} id="billing">
        <.page_header>
          Billing
          <:subtitle>{summary(@subscription, @current_scope)}</:subtitle>
        </.page_header>

        <.sign_group label="Plan">
          <.sign
            id="plan"
            icon={:billing}
            time={plan_name(@subscription, @current_scope)}
            time_label="Plan"
          >
            <:title>{plan_name(@subscription, @current_scope)} plan</:title>
            {period_text(@subscription)}
            <:actions :if={@can_manage?}>
              <.sign_action :if={upgrade?(@subscription)} id="upgrade" primary phx-click="upgrade">
                Upgrade to Pro
              </.sign_action>
              <.sign_action
                :if={fix_payment?(@subscription)}
                id="update-payment"
                primary
                phx-click="update_payment"
              >
                Update payment
              </.sign_action>
            </:actions>
          </.sign>

          <.sign
            :if={@subscription}
            id="status"
            icon={:alert}
            state={if @subscription.status == "active", do: :later, else: :next}
            time={status_word(@subscription)}
            time_label="Status"
          >
            <:title>
              <.attention_dot :if={@subscription.status != "active"} />
              {status_headline(@subscription)}
            </:title>
            {status_detail(@subscription)}
            <:actions :if={@can_manage? && cancellable?(@subscription)}>
              <.sign_action id="cancel-plan" phx-click="ask_cancel">Cancel plan</.sign_action>
            </:actions>
          </.sign>

          <.sign
            :if={@confirm_cancel?}
            id="cancel-confirm"
            icon={:alert}
            state={:next}
            draw={false}
          >
            <:title>
              Cancel {plan_name(@subscription, @current_scope)} at the end of this period?
            </:title>
            You keep access until {period_end_text(@subscription)}. After that the account becomes
            read-only; your data stays.
            <:actions>
              <.sign_action id="confirm-cancel" primary phx-click="cancel_subscription">
                Cancel plan
              </.sign_action>
              <.sign_action id="keep-plan" phx-click="keep_plan">Keep plan</.sign_action>
            </:actions>
          </.sign>
        </.sign_group>

        <.sign_group label="Invoices">
          <div id="invoices" phx-update="stream">
            <div
              id="invoices-empty"
              class="hidden border-b border-line/40 px-4 py-6 text-ink-2 only:block sm:px-[26px]"
            >
              No invoices yet.
            </div>
            <.sign
              :for={{id, invoice} <- @streams.invoices}
              id={id}
              icon={:billing}
              draw={false}
              time={Calendar.strftime(invoice.due_date, "%-d %b")}
              time_label="Due"
            >
              <:title>{invoice.invoice_number}</:title>
              {format_amount(invoice.amount)} {invoice.currency} · {String.capitalize(invoice.status)}
            </.sign>
          </div>
        </.sign_group>
      </div>
    </Layouts.app>
    """
  end

  defp summary(nil, _scope), do: "Free plan."

  defp summary(%{status: "active", cancel_at_period_end: true} = subscription, _scope),
    do: "Cancelled. Access ends #{period_end_text(subscription)}."

  defp summary(%{status: "active"} = subscription, _scope),
    do: "#{plan_name(subscription, nil)} plan, renews #{period_end_text(subscription)}."

  defp summary(%{status: "past_due"} = subscription, _scope),
    do: "Payment failed on #{period_end_text(subscription)}. Read-only until it clears."

  defp summary(%{status: "cancelled"} = subscription, _scope) do
    if paid_period_left?(subscription),
      do: "Cancelled. Access ends #{period_end_text(subscription)}.",
      else: "Cancelled. The account is read-only."
  end

  defp summary(%{status: "expired"}, _scope), do: "Expired. The account is read-only."

  defp plan_name(nil, scope), do: String.capitalize(scope.tier)
  defp plan_name(subscription, _scope), do: String.capitalize(subscription.plan_type)

  defp period_text(nil), do: "No paid plan. Upgrade to add clients and unlock more."

  defp period_text(subscription) do
    "Period #{Calendar.strftime(subscription.current_period_start, "%-d %b")} to #{period_end_text(subscription)}"
  end

  defp period_end_text(nil), do: ""

  defp period_end_text(subscription),
    do: Calendar.strftime(subscription.current_period_end, "%-d %b")

  defp status_word(%{status: "past_due"}), do: "Past due"
  defp status_word(%{status: "cancelled"}), do: "Cancelled"
  defp status_word(%{status: "expired"}), do: "Expired"
  defp status_word(_subscription), do: "Active"

  defp status_headline(%{status: status, cancel_at_period_end: true} = subscription)
       when status in ["active", "cancelled"] do
    if paid_period_left?(subscription), do: "Cancelling", else: "Cancelled"
  end

  defp status_headline(%{status: "active"}), do: "Active"

  defp status_headline(%{status: "past_due"} = subscription),
    do: "Past due since #{period_end_text(subscription)}"

  defp status_headline(%{status: "cancelled"}), do: "Cancelled"
  defp status_headline(%{status: "expired"}), do: "Expired"

  defp status_detail(%{status: "past_due"}),
    do: "You get seven days of full access after a failed payment. Clients keep using the app."

  defp status_detail(%{status: "cancelled"} = subscription) do
    if paid_period_left?(subscription),
      do: "Edits pause when the paid period ends.",
      else: "The paid period has ended. Pay to restore editing."
  end

  defp status_detail(%{status: "expired"}), do: "Pay to restore editing. Your data is safe."
  defp status_detail(_subscription), do: "Nothing needs your attention."

  defp paid_period_left?(subscription),
    do: DateTime.compare(DateTime.utc_now(), subscription.current_period_end) == :lt

  defp upgrade?(nil), do: true
  defp upgrade?(subscription), do: subscription.plan_type == "free"

  defp fix_payment?(%{status: status}) when status in ["past_due", "expired"], do: true
  defp fix_payment?(_subscription), do: false

  defp cancellable?(%{status: "active", cancel_at_period_end: false}), do: true
  defp cancellable?(_subscription), do: false

  defp format_amount(%Decimal{} = amount),
    do: amount |> Decimal.round(2) |> Decimal.to_string(:normal)

  defp format_amount(amount) when is_number(amount),
    do: :erlang.float_to_binary(amount / 1, decimals: 2)

  @impl true
  def handle_event("ask_cancel", _params, socket),
    do: {:noreply, assign(socket, :confirm_cancel?, true)}

  def handle_event("keep_plan", _params, socket),
    do: {:noreply, assign(socket, :confirm_cancel?, false)}

  def handle_event("cancel_subscription", _params, socket) do
    scope = socket.assigns.current_scope

    with :ok <- Authorization.authorize(scope, :manage, :subscription),
         {:ok, _subscription} <- Billing.cancel_subscription(socket.assigns.subscription) do
      {:noreply,
       socket
       |> assign(:confirm_cancel?, false)
       |> put_flash(:info, "Plan cancelled. Access continues until the period ends.")
       |> reload_scope()
       |> load()}
    else
      _ ->
        {:noreply,
         socket
         |> assign(:confirm_cancel?, false)
         |> put_flash(:error, "That did not save. Nothing was changed. Try again.")}
    end
  end

  # Starting a payment is not wired to Paystack from the web yet.
  def handle_event(event, _params, socket) when event in ["upgrade", "update_payment"] do
    {:noreply,
     put_flash(
       socket,
       :info,
       "Online payment is being set up. Contact support to change your plan."
     )}
  end

  # The scope carries the billing state, so refresh it after a change.
  defp reload_scope(socket) do
    assign(
      socket,
      :current_scope,
      AfyaFit.Authorization.Scope.load(socket.assigns.current_scope.user)
    )
  end
end
