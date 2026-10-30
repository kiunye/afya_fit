defmodule AfyaFitWeb.CheckoutComponents do
  @moduledoc """
  The panel on the Billing page for paying: pick a plan, pick card or M-Pesa,
  then wait for the phone prompt. State and events live in `BillingLive`.
  """
  use Phoenix.Component

  import AfyaFitWeb.CoreComponents, only: [input: 1, button: 1]
  import AfyaFitWeb.SignComponents

  alias AfyaFit.Billing.Plans

  attr :checkout, :map,
    required: true,
    doc: "%{step: :plans | :method | :waiting, plan:, payment:}"

  attr :mpesa_form, :any, required: true
  attr :card?, :boolean, default: true
  attr :mpesa?, :boolean, default: true

  def checkout_panel(assigns) do
    ~H"""
    <div id="checkout">
      <.sign_group label="Pay">
        <%= case @checkout.step do %>
          <% :plans -> %>
            <.sign
              :for={plan <- Plans.paid_plans()}
              id={"plan-#{plan}"}
              icon={:billing}
              draw={false}
              time={Plans.format(Plans.price(plan))}
              time_label="A month"
            >
              <:title>{String.capitalize(plan)}</:title>
              {plan_blurb(plan)}
              <:actions>
                <.sign_action
                  id={"choose-#{plan}"}
                  primary
                  phx-click="choose_plan"
                  phx-value-plan={plan}
                >
                  Choose {String.capitalize(plan)}
                </.sign_action>
              </:actions>
            </.sign>
          <% :method -> %>
            <.sign
              id="checkout-summary"
              icon={:billing}
              state={:next}
              draw={false}
              time={Plans.format(Plans.price(@checkout.plan))}
              time_label="For 30 days"
            >
              <:title>{String.capitalize(@checkout.plan)} plan</:title>
              Paying again before it ends adds another 30 days.
            </.sign>

            <div class="flex flex-wrap items-start gap-6 px-4 py-4 sm:px-[26px]">
              <div :if={@card?} class="space-y-2">
                <p class="text-sm text-ink-2">Card, or M-Pesa through Paystack.</p>
                <.sign_action id="pay-card" primary phx-click="pay_card">Pay by card</.sign_action>
              </div>

              <.form
                :if={@mpesa?}
                for={@mpesa_form}
                id="mpesa-form"
                phx-submit="pay_mpesa"
                class="max-w-xs space-y-2"
              >
                <.input
                  field={@mpesa_form[:phone]}
                  type="tel"
                  label="M-Pesa number"
                  placeholder="0712 345 678"
                  required
                />
                <.button type="submit" variant="primary">Pay with M-Pesa</.button>
              </.form>

              <p :if={!@card? and !@mpesa?} id="no-methods" class="text-sm text-ink-2">
                Online payment is not available yet. Contact support to change your plan.
              </p>
            </div>
          <% :waiting -> %>
            <.sign
              id="waiting"
              icon={:alert}
              state={:next}
              draw={false}
              time={Plans.format(@checkout.payment.amount)}
              time_label="To pay"
            >
              <:title>Check your phone</:title>
              We sent an M-Pesa request to {@checkout.payment.phone}. Enter your PIN to pay. This
              page updates when it goes through.
            </.sign>
        <% end %>

        <div class="px-4 pb-4 sm:px-[26px]">
          <.sign_action id="close-checkout" phx-click="close_checkout">
            {if @checkout.step == :waiting, do: "Close", else: "Cancel"}
          </.sign_action>
        </div>
      </.sign_group>
    </div>
    """
  end

  defp plan_blurb("pro"), do: "25 clients, nutrition plans, calendar and progress analytics."
  defp plan_blurb("enterprise"), do: "Unlimited clients and everything in Pro."
  defp plan_blurb(_plan), do: ""
end
