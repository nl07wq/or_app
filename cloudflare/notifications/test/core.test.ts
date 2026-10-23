import { describe, expect, it } from 'vitest';
import {
  bearerToken,
  boundedPushRetryAt,
  isPushExpired,
  notificationPayload,
  pushFreshnessDeadline,
  pushFreshnessToleranceMs,
  retryDelayMs,
  validateProjection,
} from '../src/core';

const base = {
  id: 'schedule:item@2026-10-08:-15',
  entityType: 'schedule' as const,
  entityId: 'item',
  occurrenceLocalDate: '2026-10-08',
  triggerAt: '2026-10-08T00:45:00.000Z',
  timeZone: 'Asia/Tokyo',
  privacyMode: 'titleVisible' as const,
  title: 'Meeting',
};

describe('notification backend contracts', () => {
  it('accepts exactly one Bearer credential', () => {
    expect(bearerToken(new Request('https://x', { headers: { authorization: 'Bearer secret' } }))).toBe('secret');
    expect(bearerToken(new Request('https://x', { headers: { authorization: 'secret' } }))).toBeNull();
    expect(bearerToken(new Request('https://x', { headers: { authorization: 'Bearer  secret' } }))).toBeNull();
  });

  it('normalizes valid deterministic projections', () => {
    expect(validateProjection(base)).toMatchObject({ id: base.id, title: 'Meeting' });
  });

  it('never retains title in hidden mode', () => {
    const hidden = validateProjection({ ...base, privacyMode: 'contentHidden', title: 'private' });
    expect(hidden.title).toBeNull();
    expect(notificationPayload(hidden)).not.toContain('private');
  });

  it('uses bounded exponential alarm retries', () => {
    expect(retryDelayMs(1)).toBe(30_000);
    expect(retryDelayMs(4)).toBe(240_000);
    expect(retryDelayMs(20)).toBe(3_600_000);
  });

  it('keeps sends eligible through the exact five-minute freshness deadline', () => {
    const triggerAt = Date.UTC(2026, 9, 22, 23, 0, 0);
    expect(pushFreshnessToleranceMs).toBe(5 * 60_000);
    expect(pushFreshnessDeadline(triggerAt)).toBe(triggerAt + 5 * 60_000);
    expect(isPushExpired(triggerAt, triggerAt + 4 * 60_000 + 59_000)).toBe(false);
    expect(isPushExpired(triggerAt, triggerAt + 5 * 60_000)).toBe(false);
    expect(isPushExpired(triggerAt, triggerAt + 5 * 60_000 + 1)).toBe(true);
  });

  it('never schedules a deferred subscription or retry beyond freshness', () => {
    const triggerAt = Date.UTC(2026, 9, 22, 23, 0, 0);
    const deadline = pushFreshnessDeadline(triggerAt);
    expect(
      boundedPushRetryAt(triggerAt, triggerAt + 60_000, triggerAt + 3_600_000),
    ).toBe(deadline);
    expect(
      boundedPushRetryAt(triggerAt, deadline + 1, deadline + 2),
    ).toBeNull();
  });

  it('rejects malformed projection timestamps and IDs', () => {
    expect(() => validateProjection({ ...base, id: 'contains space' })).toThrow('invalid_projection');
    expect(() => validateProjection({ ...base, triggerAt: 'not-a-time' })).toThrow('invalid_projection');
  });
});
