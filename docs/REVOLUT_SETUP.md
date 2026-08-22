# Revolut Merchant API Setup Guide

This guide covers enabling Revolut Business Merchant APIs for iFlixify Pro
payments ($8.99 one-time lifetime license), wiring the webhook to the Wasmer
edge deployment, and testing in the Revolut sandbox.

The placeholder implementation lives in `edge/public/purchase.html`:

- `startRevolutCheckout()` redirects to `REVOLUT_CHECKOUT_URL` when it is set;
  until then it shows the "Revolut checkout is being set up" modal.
- The hidden "Simulate successful payment (dev)" button (revealed via
  `?dev=1` on `/purchase.html`) sets `profiles.tier = 'pro'` directly.

## 1. Enable Revolut Business Merchant API

1. Sign in to the [Revolut Business dashboard](https://business.revolut.com/)
   with an account holding **Owner** or **Admin** role.
2. Go to **Settings → Integrations → API** (or **Developer → API keys**,
   depending on dashboard version).
3. Click **Enable API access** / **Create API key**.
4. Choose the environment:
   - **Sandbox** for testing first.
   - **Production (Live)** when going live.
5. Copy the **API key** (starts with `sk_` for secret keys). Store it as a
   Wasmer edge secret — never commit it to the repo or embed it in static HTML.
6. Under the Merchant APIs section, enable **Merchant Checkout Orders** (used
   to create payment orders and hosted checkout links).

## 2. Where to get the API keys

| Item | Where | Environment |
|---|---|---|
| Secret API key (`sk_...`) | Revolut Business → Settings → Integrations → API → Create API key | Sandbox and Live are separate keys |
| Publishable key (`pk_...`) | Same screen; safe for client-side use | Sandbox and Live |
| Webhook signing secret | **Settings → Integrations → Webhooks** (or per-API webhook screen) after creating a webhook | Shown once when created |
| Sandbox test cards | [Revolut sandbox docs — test cards](https://developer.revolut.com/docs/sandbox/test-cards) | Sandbox only |

Sandbox base URL: `https://sandbox-merchant.revolut.com/api`
Live base URL: `https://merchant.revolut.com/api`

## 3. Webhook configuration (Wasmer edge URL)

1. In the Revolut dashboard open **Settings → Integrations → Webhooks →
   Add webhook**.
2. Set the endpoint URL to the Wasmer edge deployment:

   ```
   https://iflixify.wasmer.app/api/revolut-webhook
   ```

   (Adjust the path to the actual edge function route created for webhooks.)
3. Subscribe to at minimum these events:
   - `ORDER_COMPLETED` — payment captured → set `profiles.tier = 'pro'`
   - `ORDER_CANCELLED`
   - `ORDER_PAYMENT_FAILED`
4. Copy the **webhook signing secret** and store it as a Wasmer edge secret
   (e.g. `REVOLUT_WEBHOOK_SECRET`).
5. The edge webhook handler must:
   1. Verify the Revolut signature header against the signing secret.
   2. On `ORDER_COMPLETED`, look up the customer by the email/metadata
      attached when the order was created.
   3. Set `profiles.tier = 'pro'` for that user and create/confirm their
      `licenses` row.
   4. Respond `200 OK` quickly (Revolut retries non-2xx responses).

## 4. Productionizing `purchase.html`

1. Add a Wasmer edge function (e.g. `POST /api/create-order`) that calls:

   ```
   POST https://merchant.revolut.com/api/1.0/orders
   Authorization: Bearer <secret API key>
   Content-Type: application/json

   {
     "amount": 899,
     "currency": "USD",
     "description": "iFlixify Pro - lifetime license",
     "customer_email": "<logged-in user email>",
     "metadata": { "user_id": "<supabase user id>" }
   }
   ```

   The response contains `checkout_url`.

2. In `purchase.html`, replace the static `REVOLUT_CHECKOUT_URL` placeholder:
   `startRevolutCheckout()` should call the edge function, receive
   `checkout_url`, and redirect with `window.location.href = checkout_url`.
3. Add a return/cancel URL (e.g. `/purchase.html?paid=1`) so users land back
   on the page after paying; the webhook is the source of truth for granting
   Pro, the redirect is only cosmetic.
4. Send the invoice email from the webhook handler on `ORDER_COMPLETED`
   (the page currently only shows "An invoice has been sent to your email"
   after the simulated payment).

## 5. Sandbox testing steps

1. Create a **sandbox** API key in the Revolut Business sandbox (if you do not
   have a sandbox account, create one at
   <https://developer.revolut.com/> → Sandbox).
2. Point `REVOLUT_CHECKOUT_URL` / the create-order function at
   `https://sandbox-merchant.revolut.com/api`.
3. Register the sandbox webhook pointing at your **staging** Wasmer edge URL.
4. Open `https://<staging>.wasmer.app/purchase.html?dev=1`, sign in, and click
   **Pay with Revolut** — confirm you are redirected to the sandbox hosted
   checkout.
5. Pay with a sandbox test card:
   - Success: `5555 5555 5555 5555`, any future expiry, any CVC.
   - Failure: `5105 1051 0510 5100` (declined).
6. Confirm the webhook fires and `profiles.tier` flips to `'pro'` for the
   test account, and that the device management section appears on
   `/purchase.html`.
7. Verify the failure path: a declined payment must NOT grant Pro.
8. Only after sandbox sign-off: switch the API key, base URL, and webhook to
   production values.

## Security checklist

- Secret API key and webhook signing secret live only in Wasmer edge
  secrets — never in static HTML or git.
- Always verify webhook signatures before trusting the payload.
- Grant Pro only from the server-side webhook, never from client code (the
  `?dev=1` simulate button must be removed or gated before launch; today the
  `profiles` RLS policy gates who can update a row).
- Rate-limit / authenticate the create-order endpoint so only signed-in
  users can create orders.
