import type { Batch } from '../src/domain/batch.js';
import type { BatchFilter, BatchRepository } from '../src/repositories/batch-repository.js';

export class MemoryRepository implements BatchRepository {
  private batches = new Map<string, Batch>();
  async insert(batch: Batch) {
    this.batches.set(batch.id, structuredClone(batch));
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
