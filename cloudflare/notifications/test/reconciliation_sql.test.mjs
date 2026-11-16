import { DatabaseSync } from 'node:sqlite';
import { describe, expect, it } from 'vitest';
import {
  activeProjectionIdsSql,
  cancelProjectionSql,
  installationUpsertSql,
  nextProjectionAlarmSql,
  projectionUpsertBindings,
  projectionUpsertSql,
  subscriptionUpsertSql,
} from '../src/reconciliation';

function database() {
  const db = new DatabaseSync(':memory:');
  db.exec(`CREATE TABLE projections (
    id TEXT PRIMARY KEY, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL,
    occurrence_local_date TEXT NOT NULL, trigger_at INTEGER NOT NULL,
    time_zone TEXT NOT NULL, privacy_mode TEXT NOT NULL, title TEXT,
    all_day INTEGER, start_time TEXT, end_time TEXT, end_date TEXT,
    generation TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
    delivered_at INTEGER, cancelled_at INTEGER, expired_at INTEGER,
    failed_at INTEGER, retry_at INTEGER, last_attempt_at INTEGER,
    last_result TEXT
  )`);
  db.exec('CREATE INDEX projections_due ON projections(trigger_at, retry_at)');
  db.exec(`CREATE TABLE installations (
    id TEXT PRIMARY KEY, label TEXT, created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )`);
  db.exec(`CREATE TABLE subscriptions (
    installation_id TEXT PRIMARY KEY, endpoint TEXT NOT NULL,
    p256dh TEXT NOT NULL, auth TEXT NOT NULL, updated_at INTEGER NOT NULL,
    failure_count INTEGER NOT NULL DEFAULT 0, last_result TEXT
  )`);
  return db;
}

function projection(index, overrides = {}) {
  return {
    id: `schedule:item-${index}@2026-11-17:-15`,
    entityType: 'schedule',
    entityId: `item-${index}`,
    occurrenceLocalDate: '2026-11-17',
    triggerAt: new Date(Date.UTC(2026, 10, 17, 0, index % 60)).toISOString(),
    timeZone: 'Asia/Tokyo',
    privacyMode: 'titleVisible',
    title: `Item ${index}`,
    allDay: false,
    startTime: '09:00',
    endTime: '10:00',
    endDate: null,
    ...overrides,
  };
}

function upsert(db, item, generation) {
  return Number(
    db.prepare(projectionUpsertSql).run(
      ...projectionUpsertBindings(item, generation),
    ).changes,
  );
}

describe('projection reconciliation SQL', () => {
  it('turns an identical synchronization into zero projection writes', () => {
    const db = database();
    const item = projection(1);
    expect(upsert(db, item, 'generation-1')).toBe(1);
    expect(upsert(db, item, 'generation-2')).toBe(0);
    expect(db.prepare('SELECT generation FROM projections WHERE id = ?').get(item.id)).toEqual({
      generation: 'generation-1',
    });
    db.close();
  });

  it('writes only changed, removed, or reactivated projections', () => {
    const db = database();
    const retained = projection(1);
    const removed = projection(2);
    upsert(db, retained, 'generation-1');
    upsert(db, removed, 'generation-1');

    expect(upsert(db, { ...retained, title: 'Changed' }, 'generation-2')).toBe(1);
    expect(db.prepare(cancelProjectionSql).run(Date.now(), removed.id).changes).toBe(1);
    expect(upsert(db, removed, 'generation-3')).toBe(1);
    expect(db.prepare('SELECT cancelled_at FROM projections WHERE id = ?').get(removed.id)).toEqual({
      cancelled_at: null,
    });
    db.close();
  });

  it('preserves terminal delivery for metadata-only edits and resets it for a new trigger', () => {
    const db = database();
    const item = projection(1);
    upsert(db, item, 'generation-1');
    db.prepare(
      'UPDATE projections SET delivered_at = ?, attempts = 1, last_result = ? WHERE id = ?',
    ).run(Date.now(), 'delivered:1', item.id);

    expect(upsert(db, { ...item, title: 'Renamed' }, 'generation-2')).toBe(1);
    expect(db.prepare(
      'SELECT delivered_at IS NOT NULL AS delivered, attempts FROM projections WHERE id = ?',
    ).get(item.id)).toEqual({ delivered: 1, attempts: 1 });

    expect(upsert(db, {
      ...item,
      triggerAt: new Date(Date.parse(item.triggerAt) + 60_000).toISOString(),
    }, 'generation-3')).toBe(1);
    expect(db.prepare(
      'SELECT delivered_at, attempts, last_result FROM projections WHERE id = ?',
    ).get(item.id)).toEqual({ delivered_at: null, attempts: 0, last_result: null });
    db.close();
  });

  it('eliminates the legacy full-table rewrite for the observed 448-projection set', () => {
    const db = database();
    const projections = Array.from({ length: 448 }, (_, index) => projection(index));
    for (const item of projections) upsert(db, item, 'generation-1');

    const legacyCancellation = Number(db.prepare(
      `UPDATE projections SET cancelled_at = ?
       WHERE delivered_at IS NULL AND expired_at IS NULL
       AND failed_at IS NULL AND cancelled_at IS NULL`,
    ).run(Date.now()).changes);
    const legacyReactivation = projections.reduce(
      (sum, item) => sum + upsert(db, item, 'generation-2'),
      0,
    );
    expect({ legacyCancellation, legacyReactivation }).toEqual({
      legacyCancellation: 448,
      legacyReactivation: 448,
    });

    const currentNoOpWrites = projections.reduce(
      (sum, item) => sum + upsert(db, item, 'generation-3'),
      0,
    );
    expect(currentNoOpWrites).toBe(0);
    expect(db.prepare(activeProjectionIdsSql).all()).toHaveLength(448);
    db.close();
  });

  it('performs no projection mutation for an empty stable state', () => {
    const db = database();
    expect(db.prepare(activeProjectionIdsSql).all()).toEqual([]);
    expect(db.prepare(nextProjectionAlarmSql).get()).toBeUndefined();
    expect(db.prepare(
      `UPDATE projections SET cancelled_at = ?
       WHERE delivered_at IS NULL AND expired_at IS NULL
       AND failed_at IS NULL AND cancelled_at IS NULL`,
    ).run(Date.now()).changes).toBe(0);
    db.close();
  });

  it('turns identical installation and subscription recovery into zero writes', () => {
    const db = database();
    const now = Date.now();
    const installation = db.prepare(installationUpsertSql);
    expect(installation.run('installation-id', 'iPhone', now, now).changes).toBe(1);
    expect(installation.run('installation-id', 'iPhone', now + 1, now + 1).changes).toBe(0);

    const subscription = db.prepare(subscriptionUpsertSql);
    const values = ['installation-id', 'https://push.example/sub', 'key', 'auth'];
    expect(subscription.run(...values, now).changes).toBe(1);
    expect(subscription.run(...values, now + 1).changes).toBe(0);
    expect(subscription.run(
      'installation-id',
      'https://push.example/changed',
      'key',
      'auth',
      now + 2,
    ).changes).toBe(1);
    db.close();
  });
});
