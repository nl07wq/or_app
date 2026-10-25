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

## On-time delivery investigation workflow

For one test reminder scheduled a few minutes ahead, record the app's local
date/time, IANA time zone, and projected UTC `triggerAt` before leaving the
screen. In Worker logs, correlate the same projection using the `p-xxxxxxxx`
diagnostic value and compare, in order: `reconciled`, `alarm_scheduled`,
`alarm_due`, `push_result`, and the terminal event. The timestamps separate a
missing/stale projection, incorrect UTC conversion, a late Durable Object
alarm, and a failed or deferred subscription retry. A 2xx `push_result` means
the provider accepted the request only; compare it with an iPhone/PWA observed
notification time (app open and closed) to determine any device presentation
delay. Never include a title, payload, endpoint, token, or profile identifier
in this record.

## Visible push content

For a title-visible projection, the Worker sends the event title as the Web
Push title and a body with `スケジュール` or `リマインダー`, followed by the
event's stored local wall-clock time when available. Timed events use
`HH:mm` or `HH:mm 〜 HH:mm`; all-day events use `終日`. An end that falls on a
different local date includes that date before its end time. Notification
offsets do not alter this display metadata. Content-hidden projections retain
the generic `OR-APP` / `通知があります。` payload and do not persist the title or
time metadata. The OS, including iOS, controls final line wrapping and
collapsed-notification layout.
