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
