# Trying it out in development

## Demo data

```
mix ecto.reset        # optional: start from an empty database
mix run priv/repo/seeds.exs
```

Safe to run again; each run puts every organisation back into its billing state
(dates are relative to now). It refuses to run in production. Every password is
`demo-password-123` (defined in `dev/afya_fit/dev/seeds.ex`).

| Organisation | State to look at | Sign in as |
|---|---|---|
| Njoroge Strength | Free plan, at its 3-client limit, one client archived | `wanjiru@njoroge.test` (owner) |
| Peak Performance Gym | Pro, healthy. The fullest data: 2 trainers, 10 clients (paused and archived ones too), workouts, nutrition, tasks, progress, calendar events, invoices, payments in every state | `brian@peak.test` (owner), `amina@peak.test`, `faith@peak.test` (trainers) |
| Titan Fitness Collective | Enterprise, unlimited clients | `grace@titan.test` (owner), `kevin@titan.test` |
| Grace Period Gym | Period ended 3 days ago: grace period, banner, "Update payment" | `daniel@grace.test` |
| Lapsed Fitness | Period ended 12 days ago: read-only | `esther@lapsed.test` |
| Leaving Studio | Cancelled; access until the period ends | `peter@leaving.test` |
| Suspended Club | Suspended by a platform admin: read-only | `lucy@suspended.test` |
| (platform) | Platform admin: organisations, subscriptions, users | `admin@afyafit.test` |

Clients are listed by the seed script; the first two per organisation are printed
when it finishes. Amina (Nairobi) has an event at 23:30 local, a good one to
check against UTC.

## Paying without Paystack or Daraja

With no `PAYSTACK_SECRET_KEY` and no `DARAJA_CONSUMER_KEY`, development uses a
simulator (`AfyaFit.Dev.PaymentSimulator`). Sign in as an owner (for example
`wanjiru@njoroge.test`), open **Billing**, **Upgrade to Pro**:

- **Card.** "Pay by card" opens a local page with **Pay** and **Fail** buttons and
  returns to Billing, as Paystack would.
- **M-Pesa.** Enter any Kenyan number. After about 3 seconds the "phone" answers:
  paid, or cancelled if the number ends in `0` (for example `0712 345 670`). The
  page updates by itself.

Set the real credentials (see `payments.md`) and that provider is real again; the
other stays simulated. The simulator is only compiled in development and test.

## Testing against the real sandboxes

See `payments.md`. In short: Paystack test keys work with Paystack's test cards,
and Daraja's sandbox needs a public HTTPS callback URL (a tunnel such as ngrok,
with `PHX_HOST` set to its host).
