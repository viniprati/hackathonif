import { batchNotifications, type BatchNotification } from '../src/domain/notifications.js';
import type { Batch } from '../src/domain/batch.js';
import type { BatchFilter, BatchRepository } from '../src/repositories/batch-repository.js';

export class MemoryRepository implements BatchRepository {
  private sent = new Set<string>();
  private claimed = new Set<string>();
  async pendingNotifications() {
    return this.activity.filter((n) => !this.sent.has(n.id) && !this.claimed.has(n.id));
  }
  async claimNotification(id: string) {
    if (this.claimed.has(id) || this.sent.has(id)) return false;
    this.claimed.add(id);
    return true;
  }
  async markNotificationSent(id: string) {
    this.sent.add(id);
  }
  private activity: BatchNotification[] = [];
  async notifications(offset: number, limit: number) {
    return structuredClone(this.activity)
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt) || b.id.localeCompare(a.id))
      .slice(offset, offset + limit);
  }
  private batches = new Map<string, Batch>();
  async insert(batch: Batch) {
    this.activity.push(...batchNotifications(null, batch));
    this.batches.set(batch.id, structuredClone(batch));
  }
  async insertIfAbsent(batch: Batch) {
    if (this.batches.has(batch.id)) return false;
    this.activity.push(...batchNotifications(null, batch));
    this.batches.set(batch.id, structuredClone(batch));
    return true;
  }
  async get(id: string) {
    return structuredClone(this.batches.get(id) ?? null);
  }
  private matching(filter: BatchFilter) {
    return [...this.batches.values()]
      .filter(
        (batch) =>
          (!filter.from || batch.date >= filter.from) &&
          (!filter.toExclusive || batch.date < filter.toExclusive) &&
          (!filter.status ||
            (batch.items.every((item) => item.status === 'completed') ? 'completed' : 'pending') ===
              filter.status),
      )
      .sort((a, b) => b.date.localeCompare(a.date) || a.id.localeCompare(b.id));
  }
  async list(filter: BatchFilter, offset: number, limit: number) {
    return structuredClone(this.matching(filter).slice(offset, offset + limit));
  }
  async count(filter: BatchFilter) {
    return this.matching(filter).length;
  }
  async replace(batch: Batch, expectedRevision: number) {
    if (this.batches.get(batch.id)?.revision !== expectedRevision) return false;
    this.activity.push(...batchNotifications(this.batches.get(batch.id)!, batch));
    this.batches.set(batch.id, structuredClone(batch));
    return true;
  }
}
export const credentials = {
  jwtSecret: 'only-for-automated-tests-not-a-real-secret',
  mvpCpf: '12345678900',
  mvpPassword: 'only-test-password',
};
export const input = {
  name: 'Montante de teste',
  date: '2026-10-15',
  participatingSchools: ['IFES', 'Darllin'],
  items: [{ product: 'Aipim', receivedKg: 100, unitPriceCents: 572 }],
};
