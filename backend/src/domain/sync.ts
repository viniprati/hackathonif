import { createBatch, saveAllocation, DomainError, type Batch, type CreateBatch } from './batch.js';

export interface SyncBatchInput extends Omit<CreateBatch, 'items'> {
  revision: number | null;
  items: (CreateBatch['items'][number] & {
    status: 'pending' | 'completed';
    requests: { school: string; requestedKg: number }[];
    lossKg: number | null;
  })[];
}

// Ignora IDs internos, revisão e timestamps na comparação de reenvios.
export function batchContent(batch: Batch): string {
  return JSON.stringify({
    name: batch.name,
    date: batch.date,
    participatingSchools: [...batch.participatingSchools].sort(),
    items: [...batch.items]
      .sort((a, b) => a.product.localeCompare(b.product))
      .map((item) => ({
        product: item.product,
        receivedUnits: item.receivedUnits,
        unitPriceCents: item.unitPriceCents,
        invoiceNumber: item.invoiceNumber,
        status: item.status,
        lossUnits: item.lossUnits,
        allocations: [...item.allocations].sort((a, b) => a.school.localeCompare(b.school)),
      })),
  });
}

export function syncBatch(id: string, input: SyncBatchInput, previous: Batch | null): Batch {
  let next = createBatch(input);
  next.id = id;
  if (previous) {
    next.createdAt = previous.createdAt;
    next.items = next.items.map((item) => ({
      ...item,
      id: previous.items.find((old) => old.product === item.product)?.id ?? item.id,
    }));
  }
  for (const item of input.items) {
    const target = next.items.find((line) => line.product === item.product)!;
    if (item.status === 'completed') {
      if (item.lossKg === null)
        throw new DomainError('INVALID_LOSS', 'Classifique o saldo antes de sincronizar.');
      next = saveAllocation(next, target.id, {
        revision: next.revision,
        requests: item.requests,
        remainderConfirmed: true,
        lossKg: item.lossKg,
      });
    } else if (
      item.lossKg !== null ||
      item.requests.some(
        (request) =>
          request.requestedKg !== 0 || !next.participatingSchools.includes(request.school),
      ) ||
      new Set(item.requests.map((request) => request.school)).size !== item.requests.length
    ) {
      throw new DomainError(
        'INVALID_PENDING',
        'Um alimento pendente não pode conter rateio finalizado.',
      );
    }
  }
  // Uma revisão representa a gravação atômica do montante inteiro.
  next.revision = previous ? previous.revision + 1 : 0;
  return next;
}
