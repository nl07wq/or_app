import { DurableObject } from 'cloudflare:workers';
import { buildPushPayload, type PushSubscription, type VapidKeys } from '@block65/webcrypto-web-push';
import {
  bearerToken,
  constantTimeEqual,
  decryptSecret,
  encryptSecret,
  notificationPayload,
  retryDelayMs,
  secretDigest,
  validateProjection,
  type ProjectionInput,
} from './core';

interface Env {
  PROFILES: DurableObjectNamespace<NotificationProfile>;
  ALLOWED_ORIGIN: string;
  PROFILE_PEPPER: string;
  VAPID_PUBLIC_KEY: string;
  VAPID_PRIVATE_KEY: string;
  VAPID_SUBJECT: string;
}

interface ProfileSecrets {
  profileId: string;
  profileSecret: string;
  recoverySecret: string;
}

const json = (body: unknown, status = 200, headers: HeadersInit = {}) => new Response(
  JSON.stringify(body),
  { status, headers: { 'content-type': 'application/json; charset=utf-8', ...headers } },
);

function cors(request: Request, env: Env): HeadersInit {
  const origin = request.headers.get('origin');
  return origin === env.ALLOWED_ORIGIN
    ? { 'access-control-allow-origin': origin, 'vary': 'Origin' }
    : {};
}

function validProfileId(value: string): boolean {
  return /^[A-Za-z0-9_-]{20,100}$/.test(value);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const headers = cors(request, env);
    if (request.method === 'OPTIONS') return new Response(null, {
      status: 204,
      headers: {
        ...headers,
        'access-control-allow-methods': 'GET,POST,PUT,DELETE,OPTIONS',
        'access-control-allow-headers': 'authorization,content-type,idempotency-key',
        'access-control-max-age': '86400',
      },
    });
    if (url.pathname === '/health' && request.method === 'GET') {
      return json({ status: 'ok', service: 'or-app-notifications', planContract: 'free' }, 200, headers);
    }
    if (url.pathname === '/v1/vapid-public-key' && request.method === 'GET') {
      return json({ publicKey: env.VAPID_PUBLIC_KEY }, 200, headers);
    }
    const match = url.pathname.match(/^\/v1\/profiles\/([^/]+)(\/.*)?$/);
    if (!match || !validProfileId(match[1])) return json({ error: 'not_found' }, 404, headers);
    const profileId = match[1];
    const stub = env.PROFILES.get(env.PROFILES.idFromName(profileId));
    const forwarded = new Request(`https://profile.internal${match[2] || ''}${url.search}`, request);
    forwarded.headers.set('x-or-profile-id', profileId);
    const response = await stub.fetch(forwarded);
    const resultHeaders = new Headers(response.headers);
    for (const [key, value] of Object.entries(headers)) resultHeaders.set(key, value);
    return new Response(response.body, { status: response.status, headers: resultHeaders });
  },
};

export class NotificationProfile extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.blockConcurrencyWhile(async () => {
      const sql = ctx.storage.sql;
      sql.exec(`CREATE TABLE IF NOT EXISTS profile (
        singleton INTEGER PRIMARY KEY CHECK(singleton = 1), profile_id TEXT NOT NULL,
        secret_hash TEXT NOT NULL, secret_cipher TEXT NOT NULL,
        recovery_hash TEXT NOT NULL, created_at INTEGER NOT NULL)`);
      sql.exec(`CREATE TABLE IF NOT EXISTS pairing_codes (
        code_hash TEXT PRIMARY KEY, expires_at INTEGER NOT NULL, used_at INTEGER)`);
      sql.exec(`CREATE TABLE IF NOT EXISTS installations (
        id TEXT PRIMARY KEY, label TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)`);
      sql.exec(`CREATE TABLE IF NOT EXISTS subscriptions (
        installation_id TEXT PRIMARY KEY, endpoint TEXT NOT NULL, p256dh TEXT NOT NULL,
        auth TEXT NOT NULL, updated_at INTEGER NOT NULL, failure_count INTEGER NOT NULL DEFAULT 0,
        last_result TEXT)`);
      sql.exec(`CREATE TABLE IF NOT EXISTS projections (
        id TEXT PRIMARY KEY, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL,
        occurrence_local_date TEXT NOT NULL, trigger_at INTEGER NOT NULL, time_zone TEXT NOT NULL,
        privacy_mode TEXT NOT NULL, title TEXT, generation TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0, delivered_at INTEGER, cancelled_at INTEGER,
        retry_at INTEGER, last_result TEXT)`);
      sql.exec(`CREATE INDEX IF NOT EXISTS projections_due ON projections(trigger_at, retry_at)`);
    });
  }

  async fetch(request: Request): Promise<Response> {
    try {
      const url = new URL(request.url);
      const profileId = request.headers.get('x-or-profile-id') || '';
      if (url.pathname === '' || url.pathname === '/') {
        if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
        const body = await request.json<ProfileSecrets>();
        if (body.profileId !== profileId || body.profileSecret?.length < 24 || body.recoverySecret?.length < 24) {
          return json({ error: 'invalid_profile' }, 400);
        }
        const existing = [...this.ctx.storage.sql.exec(
          'SELECT profile_id FROM profile WHERE singleton = 1',
        )][0];
        if (existing) return json({ error: 'profile_exists' }, 409);
        const secretHash = await secretDigest(body.profileSecret, this.env.PROFILE_PEPPER);
        const recoveryHash = await secretDigest(body.recoverySecret, this.env.PROFILE_PEPPER);
        const secretCipher = await encryptSecret(body.profileSecret, this.env.PROFILE_PEPPER);
        this.ctx.storage.sql.exec(
          'INSERT INTO profile(singleton, profile_id, secret_hash, secret_cipher, recovery_hash, created_at) VALUES(1, ?, ?, ?, ?, ?)',
          profileId, secretHash, secretCipher, recoveryHash, Date.now(),
        );
        return json({ profileId, created: true }, 201);
      }
      if (url.pathname === '/recover' && request.method === 'POST') {
        const body = await request.json<{ recoverySecret?: string }>();
        if (!(await this.authorizeRecovery(body.recoverySecret))) return json({ error: 'unauthorized' }, 401);
        const row = this.ctx.storage.sql.exec('SELECT secret_cipher FROM profile WHERE singleton = 1').one() as { secret_cipher: string };
        return json({ verified: true, profileSecret: await decryptSecret(row.secret_cipher, this.env.PROFILE_PEPPER) });
      }
      if (url.pathname === '/pairing/consume' && request.method === 'POST') {
        const body = await request.json<{ code?: string; installationId?: string; label?: string }>();
        if (!body.code || !body.installationId) return json({ error: 'invalid_pairing' }, 400);
        const digest = await secretDigest(body.code, this.env.PROFILE_PEPPER);
        const row = [...this.ctx.storage.sql.exec(
          'SELECT expires_at, used_at FROM pairing_codes WHERE code_hash = ?', digest,
        )][0] as { expires_at: number; used_at: number | null } | undefined;
        if (!row || row.used_at || row.expires_at < Date.now()) return json({ error: 'invalid_pairing' }, 401);
        this.ctx.storage.sql.exec('UPDATE pairing_codes SET used_at = ? WHERE code_hash = ?', Date.now(), digest);
        this.upsertInstallation(body.installationId, body.label);
        const profile = this.ctx.storage.sql.exec('SELECT secret_cipher FROM profile WHERE singleton = 1').one() as { secret_cipher: string };
        return json({ paired: true, profileSecret: await decryptSecret(profile.secret_cipher, this.env.PROFILE_PEPPER) });
      }
      if (!(await this.authorize(request))) return json({ error: 'unauthorized' }, 401);
      if (url.pathname === '/pairing' && request.method === 'POST') {
        const body = await request.json<{ code?: string }>();
        if (!body.code || body.code.length < 24) return json({ error: 'invalid_pairing_code' }, 400);
        const digest = await secretDigest(body.code, this.env.PROFILE_PEPPER);
        this.ctx.storage.sql.exec('DELETE FROM pairing_codes WHERE expires_at < ?', Date.now());
        this.ctx.storage.sql.exec('INSERT OR REPLACE INTO pairing_codes(code_hash, expires_at, used_at) VALUES(?, ?, NULL)', digest, Date.now() + 300_000);
        return json({ expiresInSeconds: 300 });
      }
      const subscription = url.pathname.match(/^\/installations\/([^/]+)\/subscription$/);
      if (subscription) return this.subscription(request, decodeURIComponent(subscription[1]));
      if (url.pathname === '/projections/reconcile' && request.method === 'PUT') return this.reconcile(request);
      if (url.pathname === '/status' && request.method === 'GET') return this.status();
      return json({ error: 'not_found' }, 404);
    } catch (error) {
      console.error('request_failed', error instanceof Error ? error.message : 'unknown');
      return json({ error: 'request_failed' }, 400);
    }
  }

  private async authorize(request: Request): Promise<boolean> {
    const token = bearerToken(request);
    if (!token) return false;
    const row = [...this.ctx.storage.sql.exec(
      'SELECT secret_hash FROM profile WHERE singleton = 1',
    )][0] as { secret_hash: string } | undefined;
    if (!row) return false;
    return constantTimeEqual(await secretDigest(token, this.env.PROFILE_PEPPER), row.secret_hash);
  }

  private async authorizeRecovery(secret?: string): Promise<boolean> {
    if (!secret) return false;
    const row = [...this.ctx.storage.sql.exec(
      'SELECT recovery_hash FROM profile WHERE singleton = 1',
    )][0] as { recovery_hash: string } | undefined;
    return !!row && constantTimeEqual(await secretDigest(secret, this.env.PROFILE_PEPPER), row.recovery_hash);
  }

  private upsertInstallation(id: string, label?: string): void {
    if (!/^[A-Za-z0-9_-]{20,100}$/.test(id)) throw new Error('invalid_installation');
    const now = Date.now();
    this.ctx.storage.sql.exec(
      `INSERT INTO installations(id, label, created_at, updated_at) VALUES(?, ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET label = excluded.label, updated_at = excluded.updated_at`,
      id, typeof label === 'string' ? label.slice(0, 80) : null, now, now,
    );
  }

  private async subscription(request: Request, installationId: string): Promise<Response> {
    if (request.method === 'DELETE') {
      this.ctx.storage.sql.exec('DELETE FROM subscriptions WHERE installation_id = ?', installationId);
      this.ctx.storage.sql.exec('DELETE FROM installations WHERE id = ?', installationId);
      return new Response(null, { status: 204 });
    }
    if (request.method !== 'PUT') return json({ error: 'method_not_allowed' }, 405);
    const body = await request.json<{ endpoint?: string; keys?: { p256dh?: string; auth?: string }; label?: string }>();
    if (!body.endpoint?.startsWith('https://') || !body.keys?.p256dh || !body.keys.auth) {
      return json({ error: 'invalid_subscription' }, 400);
    }
    this.upsertInstallation(installationId, body.label);
    this.ctx.storage.sql.exec(
      `INSERT INTO subscriptions(installation_id, endpoint, p256dh, auth, updated_at, failure_count, last_result)
       VALUES(?, ?, ?, ?, ?, 0, NULL)
       ON CONFLICT(installation_id) DO UPDATE SET endpoint=excluded.endpoint, p256dh=excluded.p256dh,
       auth=excluded.auth, updated_at=excluded.updated_at, failure_count=0, last_result=NULL`,
      installationId, body.endpoint, body.keys.p256dh, body.keys.auth, Date.now(),
    );
    await this.scheduleNextAlarm();
    return json({ subscribed: true });
  }

  private async reconcile(request: Request): Promise<Response> {
    const body = await request.json<{ generation?: string; projections?: unknown[] }>();
    if (!body.generation || !Array.isArray(body.projections) || body.projections.length > 2000) {
      return json({ error: 'invalid_reconciliation' }, 400);
    }
    const projections = body.projections.map(validateProjection);
    const ids = new Set(projections.map((item) => item.id));
    if (ids.size !== projections.length) return json({ error: 'duplicate_projection' }, 400);
    const sql = this.ctx.storage.sql;
    sql.exec('UPDATE projections SET cancelled_at = ? WHERE delivered_at IS NULL AND cancelled_at IS NULL', Date.now());
    for (const item of projections) {
      sql.exec(
        `INSERT INTO projections(id, entity_type, entity_id, occurrence_local_date, trigger_at,
         time_zone, privacy_mode, title, generation, attempts, delivered_at, cancelled_at, retry_at, last_result)
         VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, 0, NULL, NULL, NULL, NULL)
         ON CONFLICT(id) DO UPDATE SET entity_type=excluded.entity_type, entity_id=excluded.entity_id,
         occurrence_local_date=excluded.occurrence_local_date, trigger_at=excluded.trigger_at,
         time_zone=excluded.time_zone, privacy_mode=excluded.privacy_mode, title=excluded.title,
         generation=excluded.generation, cancelled_at=NULL,
         delivered_at=CASE WHEN projections.trigger_at != excluded.trigger_at THEN NULL ELSE projections.delivered_at END,
         attempts=CASE WHEN projections.trigger_at != excluded.trigger_at THEN 0 ELSE projections.attempts END,
         retry_at=CASE WHEN projections.trigger_at != excluded.trigger_at THEN NULL ELSE projections.retry_at END,
         last_result=CASE WHEN projections.trigger_at != excluded.trigger_at THEN NULL ELSE projections.last_result END`,
        item.id, item.entityType, item.entityId, item.occurrenceLocalDate,
        Date.parse(item.triggerAt), item.timeZone, item.privacyMode, item.title ?? null, body.generation,
      );
    }
    await this.scheduleNextAlarm();
    return json({ generation: body.generation, accepted: projections.length });
  }

  private status(): Response {
    const sql = this.ctx.storage.sql;
    const installations = sql.exec('SELECT COUNT(*) AS count FROM installations').one() as { count: number };
    const subscriptions = sql.exec('SELECT COUNT(*) AS count FROM subscriptions').one() as { count: number };
    const pending = sql.exec('SELECT COUNT(*) AS count FROM projections WHERE delivered_at IS NULL AND cancelled_at IS NULL').one() as { count: number };
    const next = sql.exec('SELECT MIN(COALESCE(retry_at, trigger_at)) AS value FROM projections WHERE delivered_at IS NULL AND cancelled_at IS NULL').one() as { value: number | null };
    const failed = sql.exec('SELECT COUNT(*) AS count FROM subscriptions WHERE failure_count > 0').one() as { count: number };
    const last = [...sql.exec(
      'SELECT last_result FROM projections WHERE last_result IS NOT NULL ORDER BY COALESCE(delivered_at, retry_at, trigger_at) DESC LIMIT 1',
    )][0] as { last_result: string } | undefined;
    return json({
      installations: installations.count,
      subscriptions: subscriptions.count,
      pendingProjections: pending.count,
      nextTriggerAt: next.value ? new Date(next.value).toISOString() : null,
      lastPushResult: last?.last_result ?? null,
      failedSubscriptions: failed.count,
      quotaState: 'free-tier-limits-not-exposed-by-runtime',
    });
  }

  async alarm(): Promise<void> {
    const now = Date.now();
    const due = [...this.ctx.storage.sql.exec(
      `SELECT * FROM projections WHERE delivered_at IS NULL AND cancelled_at IS NULL
       AND COALESCE(retry_at, trigger_at) <= ? ORDER BY COALESCE(retry_at, trigger_at) LIMIT 50`, now,
    )] as unknown as Array<Record<string, string | number | null>>;
    for (const row of due) await this.deliver(row);
    await this.scheduleNextAlarm();
  }

  private async deliver(row: Record<string, string | number | null>): Promise<void> {
    const subscriptions = [...this.ctx.storage.sql.exec('SELECT * FROM subscriptions')] as unknown as Array<Record<string, string | number>>;
    if (subscriptions.length === 0) {
      this.ctx.storage.sql.exec(
        'UPDATE projections SET last_result = ?, retry_at = ? WHERE id = ?',
        'no_subscription', Date.now() + 3_600_000, row.id,
      );
      return;
    }
    const projection: ProjectionInput = {
      id: String(row.id), entityType: row.entity_type as 'schedule' | 'reminder',
      entityId: String(row.entity_id), occurrenceLocalDate: String(row.occurrence_local_date),
      triggerAt: new Date(Number(row.trigger_at)).toISOString(), timeZone: String(row.time_zone),
      privacyMode: row.privacy_mode as ProjectionInput['privacyMode'], title: row.title ? String(row.title) : null,
    };
    const vapid: VapidKeys = {
      subject: this.env.VAPID_SUBJECT,
      publicKey: this.env.VAPID_PUBLIC_KEY,
      privateKey: this.env.VAPID_PRIVATE_KEY,
    };
    let retryable = false;
    let success = 0;
    for (const value of subscriptions) {
      try {
        const subscription: PushSubscription = {
          endpoint: String(value.endpoint), expirationTime: null,
          keys: { p256dh: String(value.p256dh), auth: String(value.auth) },
        };
        const init = await buildPushPayload({ data: notificationPayload(projection), options: { ttl: 300 } }, subscription, vapid);
        const response = await fetch(subscription.endpoint, init);
        if (response.ok) {
          success++;
          this.ctx.storage.sql.exec('UPDATE subscriptions SET failure_count=0, last_result=? WHERE installation_id=?', `ok:${response.status}`, value.installation_id);
        } else if (response.status === 404 || response.status === 410) {
          this.ctx.storage.sql.exec('DELETE FROM subscriptions WHERE installation_id=?', value.installation_id);
        } else {
          retryable = response.status === 429 || response.status >= 500;
          this.ctx.storage.sql.exec('UPDATE subscriptions SET failure_count=failure_count+1, last_result=? WHERE installation_id=?', `http:${response.status}`, value.installation_id);
        }
      } catch {
        retryable = true;
        this.ctx.storage.sql.exec('UPDATE subscriptions SET failure_count=failure_count+1, last_result=? WHERE installation_id=?', 'network_error', value.installation_id);
      }
    }
    const attempts = Number(row.attempts) + 1;
    if (success > 0 || !retryable || attempts >= 4) {
      this.ctx.storage.sql.exec('UPDATE projections SET delivered_at=?, attempts=?, retry_at=NULL, last_result=? WHERE id=?', Date.now(), attempts, success > 0 ? `delivered:${success}` : 'failed_final', row.id);
    } else {
      this.ctx.storage.sql.exec('UPDATE projections SET attempts=?, retry_at=?, last_result=? WHERE id=?', attempts, Date.now() + retryDelayMs(attempts), 'retry_scheduled', row.id);
    }
  }

  private async scheduleNextAlarm(): Promise<void> {
    const row = this.ctx.storage.sql.exec(
      'SELECT MIN(COALESCE(retry_at, trigger_at)) AS value FROM projections WHERE delivered_at IS NULL AND cancelled_at IS NULL',
    ).one() as { value: number | null };
    if (row.value) await this.ctx.storage.setAlarm(Math.max(Date.now() + 1000, row.value));
    else await this.ctx.storage.deleteAlarm();
  }
}
