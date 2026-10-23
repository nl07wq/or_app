# OR-APP Notifications Worker

Cloudflare Workers Free deployment using one SQLite-backed Durable Object per
Notification Profile. Durable Object alarms deliver standards-based encrypted
Web Push using VAPID. The Worker stores only derived future projections and
device subscriptions; IndexedDB remains authoritative.

Required Worker secrets:

- `PROFILE_PEPPER`
- `VAPID_PUBLIC_KEY`
- `VAPID_PRIVATE_KEY`

`VAPID_SUBJECT` and the allowed GitHub Pages origin are non-secret Wrangler
variables. Never place profile secrets, recovery secrets, subscriptions, or
private VAPID material in source control.

## Delivery freshness and diagnostics

The Durable Object suppresses a projection once more than five minutes have
elapsed after its `trigger_at` instant. Expired projections are terminal and
are not retried, including deferred no-subscription deliveries. The authorized
`/status` endpoint reports aggregate delivered, expired, failed, and cancelled
projection counts; structured Worker diagnostics contain only timestamps,
lateness, retry count, and HTTP result class/network error. A successful Web
Push HTTP response means the push provider accepted the request—it does not
confirm that a device displayed the notification.

Deploy only after the required secrets and intended Cloudflare account are
verified: `pnpm run deploy`. Do not create or replace secrets as part of a
normal source deployment.
