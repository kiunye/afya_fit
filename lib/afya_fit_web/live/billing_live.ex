defmodule AfyaFitWeb.BillingLive do
  @moduledoc """
  Billing: the organization's plan, its status and invoices. Organization
  admins manage it; platform admins can read it.
  """
  use AfyaFitWeb, :live_view

  import AfyaFitWeb.SignComponents

  alias AfyaFit.{Authorization, Billing}
  alias AfyaFit.Authorization.BillingStatus
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
    zone = AfyaFit.Timezone.zone(scope)

    subscription =
      scope.user.organization_id
      |> Billing.get_subscription_by_organization()
      |> localize_subscription(zone)

    invoices = if subscription, do: Billing.list_invoices(subscription.id), else: []

    socket
    |> assign(:subscription, subscription)
    |> assign(:status, subscription |> status_of(scope) |> localize_status(zone))
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
          <:subtitle>{summary(@subscription, @status, @current_scope)}</:subtitle>
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
                :if={fix_payment?(@status)}
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
            state={if @status.reason, do: :next, else: :later}
            time={status_word(@status)}
            time_label="Status"
          >
            <:title><.attention_dot :if={@status.reason} /> {status_headline(@status)}</:title>
             {status_detail(@status)}
            <:actions :if={@can_manage? && cancellable?(@subscription, @status)}>
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

  defp plan_name(nil, scope), do: String.capitalize(scope.tier)
  defp plan_name(subscription, _scope), do: String.capitalize(subscription.plan_type)

  defp period_text(nil), do: "No paid plan. Upgrade to add clients and unlock more."

  defp period_text(subscription) do
    "Period #{Calendar.strftime(subscription.current_period_start, "%-d %b")} to #{period_end_text(subscription)}"
  end

  defp period_end_text(nil), do: ""

  defp period_end_text(subscription),
    do: Calendar.strftime(subscription.current_period_end, "%-d %b")

  # Dates are shown in the viewer's zone; shifting the zone keeps the same instant.
  defp localize_subscription(nil, _zone), do: nil

  defp localize_subscription(subscription, zone) do
    %{
      subscription
      | current_period_start: AfyaFit.Timezone.to_local(subscription.current_period_start, zone),
        current_period_end: AfyaFit.Timezone.to_local(subscription.current_period_end, zone)
    }
  end

  defp localize_status(%BillingStatus{} = status, zone) do
    %{status | since: localize(status.since, zone), until: localize(status.until, zone)}
  end

  defp localize(nil, _zone), do: nil
  defp localize(datetime, zone), do: AfyaFit.Timezone.to_local(datetime, zone)

  defp upgrade?(nil), do: true
  defp upgrade?(subscription), do: subscription.plan_type == "free"

  # Everything about billing state comes from one BillingStatus.
  defp status_of(nil, _scope), do: %BillingStatus{state: :active}

  defp status_of(subscription, scope) do
    BillingStatus.build(
      %{
        subscription_status: subscription.status,
        period_end: subscription.current_period_end,
        cancel_at_period_end: subscription.cancel_at_period_end,
        organization_status: scope.organization_status
      },
      DateTime.utc_now()
    )
  end

  defp summary(nil, _status, _scope), do: "Free plan."

  defp summary(subscription, status, _scope) do
    case status.reason do
      nil ->
        "#{plan_name(subscription, nil)} plan, renews #{period_end_text(subscription)}."

      :grace ->
        "Payment failed on #{date(status.since)}. Full access until #{date(status.until)}."

      :cancelling ->
        "Cancelled. Access ends #{date(status.until)}."

      :past_due ->
        "Payment failed on #{date(status.since)}. Read-only until it clears."

      :cancelled ->
        "Cancelled. The account is read-only."

      :expired ->
        "Expired. The account is read-only."

      :inactive ->
        "This organisation is not active."
    end
  end

  defp status_word(%{reason: reason}) when reason in [:grace, :past_due], do: "Past due"
  defp status_word(%{reason: :cancelling}), do: "Cancelling"
  defp status_word(%{reason: :cancelled}), do: "Cancelled"
  defp status_word(%{reason: :expired}), do: "Expired"
  defp status_word(%{reason: :inactive}), do: "Inactive"
  defp status_word(_status), do: "Active"

  defp status_headline(%{reason: reason} = status) when reason in [:grace, :past_due],
    do: "Past due since #{date(status.since)}"

  defp status_headline(status), do: status_word(status)

  defp status_detail(%{reason: :grace}),
    do: "You get seven days of full access after a failed payment. Clients keep using the app."

  defp status_detail(%{reason: :past_due}),
    do: "Pay to restore editing. Clients keep using the app."

  defp status_detail(%{reason: :cancelling}), do: "Edits pause when the paid period ends."

  defp status_detail(%{reason: :cancelled}),
    do: "The paid period has ended. Pay to restore editing."

  defp status_detail(%{reason: :expired}), do: "Pay to restore editing. Your data is safe."
  defp status_detail(%{reason: :inactive}), do: "Contact support to reactivate this organisation."
  defp status_detail(_status), do: "Nothing needs your attention."

  defp fix_payment?(%{reason: reason}), do: reason in [:grace, :past_due, :expired]

  defp cancellable?(subscription, status),
    do: is_nil(status.reason) and subscription.status == "active"

  defp date(datetime), do: Calendar.strftime(datetime, "%-d %b")

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
