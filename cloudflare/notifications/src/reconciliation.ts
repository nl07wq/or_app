import type { ProjectionInput } from './core';

export const projectionFingerprintStorageKey = 'projection-set-fingerprint-v1';

export const installationUpsertSql = `INSERT INTO installations(
  id, label, created_at, updated_at
) VALUES(?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  label=excluded.label,
  updated_at=excluded.updated_at
WHERE installations.label IS NOT excluded.label`;

export const subscriptionUpsertSql = `INSERT INTO subscriptions(
  installation_id, endpoint, p256dh, auth, updated_at, failure_count, last_result
) VALUES(?, ?, ?, ?, ?, 0, NULL)
ON CONFLICT(installation_id) DO UPDATE SET
  endpoint=excluded.endpoint,
  p256dh=excluded.p256dh,
  auth=excluded.auth,
  updated_at=excluded.updated_at,
  failure_count=0,
  last_result=NULL
WHERE subscriptions.endpoint IS NOT excluded.endpoint
OR subscriptions.p256dh IS NOT excluded.p256dh
OR subscriptions.auth IS NOT excluded.auth`;

export const activeProjectionIdsSql = `SELECT id FROM projections
  WHERE delivered_at IS NULL AND expired_at IS NULL AND failed_at IS NULL AND cancelled_at IS NULL`;

export const cancelProjectionSql = `UPDATE projections SET cancelled_at = ?
  WHERE id = ? AND delivered_at IS NULL AND expired_at IS NULL
  AND failed_at IS NULL AND cancelled_at IS NULL`;

export const nextProjectionAlarmSql = `SELECT id, trigger_at,
  COALESCE(retry_at, trigger_at) AS due_at
FROM projections
WHERE delivered_at IS NULL AND expired_at IS NULL
  AND failed_at IS NULL AND cancelled_at IS NULL
ORDER BY due_at LIMIT 1`;

/**
 * SQLite's conditional UPSERT is the final guard against write amplification.
 * A new client generation is intentionally not a material change: generation
 * identifies the request that last changed a projection, not a reason to
 * rewrite an otherwise identical row.
 */
export const projectionUpsertSql = `INSERT INTO projections(
  id, entity_type, entity_id, occurrence_local_date, trigger_at,
  time_zone, privacy_mode, title, all_day, start_time, end_time, end_date,
  generation, attempts, delivered_at, cancelled_at, expired_at, failed_at,
  retry_at, last_result
) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, NULL, NULL, NULL, NULL, NULL, NULL)
ON CONFLICT(id) DO UPDATE SET
  entity_type=excluded.entity_type,
  entity_id=excluded.entity_id,
  occurrence_local_date=excluded.occurrence_local_date,
  trigger_at=excluded.trigger_at,
  time_zone=excluded.time_zone,
  privacy_mode=excluded.privacy_mode,
  title=excluded.title,
  all_day=excluded.all_day,
  start_time=excluded.start_time,
  end_time=excluded.end_time,
  end_date=excluded.end_date,
  generation=excluded.generation,
  cancelled_at=CASE
    WHEN projections.trigger_at IS NOT excluded.trigger_at THEN NULL
    WHEN projections.delivered_at IS NOT NULL OR projections.expired_at IS NOT NULL OR projections.failed_at IS NOT NULL
      THEN projections.cancelled_at
    ELSE NULL
  END,
  delivered_at=CASE WHEN projections.trigger_at IS NOT excluded.trigger_at THEN NULL ELSE projections.delivered_at END,
  expired_at=CASE WHEN projections.trigger_at IS NOT excluded.trigger_at THEN NULL ELSE projections.expired_at END,
  failed_at=CASE WHEN projections.trigger_at IS NOT excluded.trigger_at THEN NULL ELSE projections.failed_at END,
  attempts=CASE WHEN projections.trigger_at IS NOT excluded.trigger_at THEN 0 ELSE projections.attempts END,
  retry_at=CASE WHEN projections.trigger_at IS NOT excluded.trigger_at THEN NULL ELSE projections.retry_at END,
  last_attempt_at=CASE WHEN projections.trigger_at IS NOT excluded.trigger_at THEN NULL ELSE projections.last_attempt_at END,
  last_result=CASE WHEN projections.trigger_at IS NOT excluded.trigger_at THEN NULL ELSE projections.last_result END
WHERE
  projections.entity_type IS NOT excluded.entity_type OR
  projections.entity_id IS NOT excluded.entity_id OR
  projections.occurrence_local_date IS NOT excluded.occurrence_local_date OR
  projections.trigger_at IS NOT excluded.trigger_at OR
  projections.time_zone IS NOT excluded.time_zone OR
  projections.privacy_mode IS NOT excluded.privacy_mode OR
  projections.title IS NOT excluded.title OR
  projections.all_day IS NOT excluded.all_day OR
  projections.start_time IS NOT excluded.start_time OR
  projections.end_time IS NOT excluded.end_time OR
  projections.end_date IS NOT excluded.end_date OR
  (
    projections.delivered_at IS NULL AND
    projections.expired_at IS NULL AND
    projections.failed_at IS NULL AND
    projections.cancelled_at IS NOT NULL
  )`;

export function projectionUpsertBindings(
  item: ProjectionInput,
  generation: string,
): Array<string | number | null> {
  return [
    item.id,
    item.entityType,
    item.entityId,
    item.occurrenceLocalDate,
    Date.parse(item.triggerAt),
    item.timeZone,
    item.privacyMode,
    item.title ?? null,
    item.allDay ? 1 : null,
    item.startTime ?? null,
    item.endTime ?? null,
    item.endDate ?? null,
    generation,
  ];
}

/** Order-independent digest of the authoritative notification state. */
export async function projectionSetFingerprint(
  projections: ProjectionInput[],
): Promise<string> {
  const canonical = [...projections].sort((first, second) =>
    first.id.localeCompare(second.id),
  );
  const bytes = new TextEncoder().encode(JSON.stringify(canonical));
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

export type AlarmMutation =
  | { action: 'none' }
  | { action: 'delete' }
  | { action: 'set'; scheduledAt: number };

export interface AlarmScheduleResult {
  mutation: AlarmMutation;
  sqlRowsRead: number;
  storageRowsRead: number;
}

/**
 * Keep the existing alarm when it already represents the required wake-up.
 * For overdue work, an earlier alarm is always preferable to delaying it just
 * because another reconciliation arrived a few milliseconds later.
 */
export function requiredAlarmMutation(
  currentAlarm: number | null,
  nextDueAt: number | null,
  now: number,
): AlarmMutation {
  if (nextDueAt === null) {
    return currentAlarm === null ? { action: 'none' } : { action: 'delete' };
  }
  if (nextDueAt > now) {
    return currentAlarm === nextDueAt
      ? { action: 'none' }
      : { action: 'set', scheduledAt: nextDueAt };
  }
  const scheduledAt = now + 1000;
  return currentAlarm !== null && currentAlarm <= scheduledAt
    ? { action: 'none' }
    : { action: 'set', scheduledAt };
}
