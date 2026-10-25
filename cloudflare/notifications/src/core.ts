export type PrivacyMode = 'titleVisible' | 'contentHidden';

export interface ProjectionInput {
  id: string;
  entityType: 'schedule' | 'reminder';
  entityId: string;
  occurrenceLocalDate: string;
  triggerAt: string;
  timeZone: string;
  privacyMode: PrivacyMode;
  title?: string | null;
  allDay?: boolean;
  startTime?: string | null;
  endTime?: string | null;
  endDate?: string | null;
}

/**
 * A push must leave the Worker no later than this window after its own
 * trigger.  Web Push TTL only controls provider retention after send, so it
 * cannot be used for this pre-send safety boundary.
 */
export const pushFreshnessToleranceMs = 5 * 60 * 1000;

export function pushFreshnessDeadline(triggerAtMs: number): number {
  return triggerAtMs + pushFreshnessToleranceMs;
}

/** The exact deadline is eligible; any later instant is terminally stale. */
export function isPushExpired(triggerAtMs: number, nowMs: number): boolean {
  return nowMs > pushFreshnessDeadline(triggerAtMs);
}

/**
 * Keep deferred subscription and transport retries inside the send window.
 * The returned deadline is intentionally rechecked by the Worker before
 * every outbound request because an alarm may resume late.
 */
export function boundedPushRetryAt(
  triggerAtMs: number,
  nowMs: number,
  requestedRetryAtMs: number,
): number | null {
  if (isPushExpired(triggerAtMs, nowMs)) return null;
  return Math.min(requestedRetryAtMs, pushFreshnessDeadline(triggerAtMs));
}

/// Stable non-secret log correlation. It deliberately never exposes the
/// projection identity (which can contain local record identifiers).
export function projectionCorrelationId(projectionId: string): string {
  let hash = 0x811c9dc5;
  for (let index = 0; index < projectionId.length; index++) {
    hash ^= projectionId.charCodeAt(index);
    hash = Math.imul(hash, 0x01000193);
  }
  return `p-${(hash >>> 0).toString(16).padStart(8, '0')}`;
}

const idPattern = /^[A-Za-z0-9_.:@-]{1,180}$/;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;
const wallTimePattern = /^([01]\d|2[0-3]):[0-5]\d$/;

export function bearerToken(request: Request): string | null {
  const value = request.headers.get('authorization');
  if (!value?.startsWith('Bearer ')) return null;
  const token = value.slice(7);
  return token && token === token.trim() ? token : null;
}

export function validateProjection(value: unknown): ProjectionInput {
  if (!value || typeof value !== 'object') throw new Error('invalid_projection');
  const item = value as Record<string, unknown>;
  if (
    typeof item.id !== 'string' || !idPattern.test(item.id) ||
    (item.entityType !== 'schedule' && item.entityType !== 'reminder') ||
    typeof item.entityId !== 'string' || !idPattern.test(item.entityId) ||
    typeof item.occurrenceLocalDate !== 'string' || !datePattern.test(item.occurrenceLocalDate) ||
    typeof item.timeZone !== 'string' || item.timeZone.length < 3 || item.timeZone.length > 80 ||
    (item.privacyMode !== 'titleVisible' && item.privacyMode !== 'contentHidden')
  ) throw new Error('invalid_projection');
  const trigger = typeof item.triggerAt === 'string' ? Date.parse(item.triggerAt) : NaN;
  if (!Number.isFinite(trigger)) throw new Error('invalid_projection');
  const title = item.privacyMode === 'titleVisible' && typeof item.title === 'string'
    ? item.title.trim().slice(0, 120)
    : null;
  const displayTime = (value: unknown): string | null =>
    item.privacyMode === 'titleVisible' && typeof value === 'string' && wallTimePattern.test(value)
      ? value
      : null;
  const endDate = item.privacyMode === 'titleVisible' && typeof item.endDate === 'string' && datePattern.test(item.endDate)
    ? item.endDate
    : null;
  return {
    id: item.id,
    entityType: item.entityType,
    entityId: item.entityId,
    occurrenceLocalDate: item.occurrenceLocalDate,
    triggerAt: new Date(trigger).toISOString(),
    timeZone: item.timeZone,
    privacyMode: item.privacyMode,
    title: title || null,
    allDay: item.privacyMode === 'titleVisible' && item.allDay === true,
    startTime: displayTime(item.startTime),
    endTime: displayTime(item.endTime),
    endDate,
  };
}

export function retryDelayMs(attempt: number): number {
  return Math.min(60 * 60_000, 30_000 * 2 ** Math.max(0, attempt - 1));
}

export function notificationPayload(projection: ProjectionInput): string {
  const category = projection.entityType === 'schedule' ? 'スケジュール' : 'リマインダー';
  const time = projection.allDay
    ? '終日'
    : projection.startTime
      ? projection.endTime
        ? `${projection.startTime} 〜 ${projection.endDate && projection.endDate !== projection.occurrenceLocalDate ? `${projection.endDate} ` : ''}${projection.endTime}`
        : projection.startTime
      : null;
  return JSON.stringify({
    title: projection.privacyMode === 'titleVisible' && projection.title
      ? projection.title
      : 'OR-APP',
    body: projection.privacyMode === 'titleVisible'
      ? time ? `${category}\n${time}` : category
      : '通知があります。',
    tag: projection.id,
    url: '/or_app/',
  });
}

export async function secretDigest(secret: string, pepper: string): Promise<string> {
  const bytes = new TextEncoder().encode(`${pepper}\u0000${secret}`);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

function base64Url(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function fromBase64Url(value: string): Uint8Array {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const binary = atob(normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '='));
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

async function encryptionKey(pepper: string): Promise<CryptoKey> {
  const material = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(pepper));
  return crypto.subtle.importKey('raw', material, 'AES-GCM', false, ['encrypt', 'decrypt']);
}

export async function encryptSecret(secret: string, pepper: string): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv }, await encryptionKey(pepper), new TextEncoder().encode(secret),
  );
  return `${base64Url(iv)}.${base64Url(new Uint8Array(encrypted))}`;
}

export async function decryptSecret(value: string, pepper: string): Promise<string> {
  const [iv, body] = value.split('.');
  if (!iv || !body) throw new Error('invalid_secret_cipher');
  const ivBytes = fromBase64Url(iv);
  const encryptedBytes = fromBase64Url(body);
  const decrypted = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: ivBytes.buffer as ArrayBuffer },
    await encryptionKey(pepper),
    encryptedBytes.buffer as ArrayBuffer,
  );
  return new TextDecoder().decode(decrypted);
}

export function constantTimeEqual(first: string, second: string): boolean {
  if (first.length !== second.length) return false;
  let different = 0;
  for (let index = 0; index < first.length; index++) {
    different |= first.charCodeAt(index) ^ second.charCodeAt(index);
  }
  return different === 0;
}
