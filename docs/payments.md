# Online payments

Organisation owners pay for a plan from **Billing**, by card (Paystack's hosted
checkout) or by M-Pesa (an STK push through Safaricom's Daraja API). Each
payment buys one 30-day period; paying again before it ends adds another 30
days. Paying while past due clears the read-only state.

## Prices

Whole Kenyan shillings a month, in `AfyaFit.Billing.Plans`:

| Plan       | Price     | Clients   |
|------------|-----------|-----------|
| Free       | 0         | 3         |
| Pro        | KES 1,500 | 25        |
| Enterprise | KES 5,000 | Unlimited |

Override with `PLAN_PRICE_PRO` and `PLAN_PRICE_ENTERPRISE`.

## Setup

Paystack:

- `PAYSTACK_SECRET_KEY` (or the `paystack_secret_key` Docker secret).
- In the Paystack dashboard, set the webhook URL to
  `https://<host>/webhooks/paystack`. Events are accepted only with a valid
  `x-paystack-signature` (HMAC-SHA512 of the raw body with the secret key).

Daraja (M-Pesa). Without these, M-Pesa is simply not offered:

| Variable                  | Value                                              |
|---------------------------|----------------------------------------------------|
| `DARAJA_CONSUMER_KEY`     | From the Daraja app                                |
| `DARAJA_CONSUMER_SECRET`  | From the Daraja app                                |
| `DARAJA_SHORTCODE`        | Paybill or Till number                             |
| `DARAJA_PASSKEY`          | Lipa Na M-Pesa Online passkey                      |
| `DARAJA_TRANSACTION_TYPE` | `CustomerPayBillOnline` (default) or `CustomerBuyGoodsOnline` for a Till |
| `DARAJA_BASE_URL`         | Sandbox by default; `https://api.safaricom.co.ke` for production |

Daraja calls back to `https://<host>/webhooks/mpesa/<token>`, so the app must be
reachable over HTTPS (use a tunnel in development). The token is unique per
payment and unguessable; Daraja's callbacks are not signed, so a success is also
confirmed with an STK query before it counts.

## How a payment settles

Every attempt is a row in `payments` (`pending`, `succeeded`, `failed` or
`expired`). `Billing.Checkout.settle/2` is idempotent: it locks the row, and a
second report of the same payment changes nothing. Three things can settle one:

1. the provider's webhook,
2. the customer returning from Paystack (`/billing?reference=...`),
3. `PaymentReconcileWorker`, every 5 minutes, for webhooks that never arrived.

Amounts and currency are checked on every path; less than the price fails the
payment. Cash that arrives after a payment expired still counts.

## Not covered yet

- Card payments do not renew by themselves; reminders prompt people to pay
  again. Paystack subscriptions can be added without changing `payments`.
- The mobile app still shows "Contact us" for plan changes.
- No refunds from the app; do them in the provider's dashboard.
