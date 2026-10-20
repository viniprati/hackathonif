import { randomUUID } from 'node:crypto';
import { foods, invoices, schools } from './catalog.js';

export class DomainError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly status = 422,
  ) {
    super(message);
  }
}
export interface Allocation {
  school: string;
  requestedUnits: number;
  allocatedUnits: number;
}
export interface Item {
  id: string;
  product: string;
  receivedUnits: number;
  unitPriceCents: number | null;
  invoiceNumber: string | null;
  status: 'pending' | 'completed';
  lossUnits: number | null;
  allocations: Allocation[];
}
export interface Batch {
  id: string;
  name: string;
  date: string;
  participatingSchools: string[];
  revision: number;
  items: Item[];
  createdAt: string;
  updatedAt: string;
}
export interface CreateBatch {
  name: string;
  date: string;
  participatingSchools: string[];
  items: {
    product: string;
    receivedKg: number;
    unitPriceCents?: number | null;
    invoiceNumber?: string | null;
  }[];
}
export interface SaveAllocation {
  revision: number;
  requests: { school: string; requestedKg: number }[];
  remainderConfirmed?: boolean;
  lossKg?: number;
}
export function units(kg: number, allowZero = true): number {
  if (
    !Number.isFinite(kg) ||
    kg < (allowZero ? 0 : 0.1) ||
    kg > 1_000_000 ||
    Math.abs(kg * 10 - Math.round(kg * 10)) > 1e-7
  ) {
    throw new DomainError(
      'INVALID_QUANTITY',
      'Informe quantidades em passos de 0,1 kg, até 1.000.000 kg.',
    );
  }
  return Math.round(kg * 10);
}
export function validDate(date: string): string {
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(date) ||
    !Number.isFinite(Date.parse(date)) ||
    new Date(date).toISOString().slice(0, 10) !== date ||
    date < '2020-01-01' ||
    date > '2100-12-31'
  ) {
    throw new DomainError(
      'INVALID_DATE',
      'Informe uma data válida entre 2020 e 2100 no formato AAAA-MM-DD.',
    );
  }
  return date;
}
export function createBatch(input: CreateBatch): Batch {
  const name = input.name.trim();
  if (name.length < 1 || name.length > 120)
    throw new DomainError('INVALID_NAME', 'Informe o nome do montante (até 120 caracteres).');
  const selected = input.participatingSchools;
  if (
    selected.length === 0 ||
    new Set(selected).size !== selected.length ||
    selected.some((school) => !schools.includes(school as (typeof schools)[number]))
  ) {
    throw new DomainError('INVALID_SCHOOLS', 'Selecione escolas cadastradas, sem repetições.');
  }
  if (
    input.items.length < 1 ||
    input.items.length > foods.length ||
    new Set(input.items.map((item) => item.product)).size !== input.items.length
  ) {
    throw new DomainError('INVALID_ITEMS', 'Escolha de um a dez alimentos, sem repetições.');
  }
  const participants = schools.filter((school) => selected.includes(school));
  const now = new Date().toISOString();
  return {
    id: randomUUID(),
    name,
    date: validDate(input.date),
    participatingSchools: participants,
    revision: 0,
    createdAt: now,
    updatedAt: now,
    items: input.items.map((item) => {
      if (!foods.some((food) => food.name === item.product))
        throw new DomainError('UNKNOWN_FOOD', 'Use apenas alimentos do catálogo.');
      const price = item.unitPriceCents ?? null;
      if (price !== null && (!Number.isSafeInteger(price) || price < 0 || price > 1_000_000)) {
        throw new DomainError(
          'INVALID_PRICE',
          'Informe o preço em centavos, entre zero e 1.000.000.',
        );
      }
      const invoice = item.invoiceNumber ?? null;
      if (
        invoice !== null &&
        !invoices.some(
          (reference) =>
            reference.number === invoice &&
            reference.items.some(
              (line) => line.food === item.product && line.unitPriceCents === price,
            ),
        )
      ) {
        throw new DomainError(
          'INVOICE_MISMATCH',
          'Alimento ou preço não corresponde à nota de referência.',
        );
      }
      return {
        id: randomUUID(),
        product: item.product,
        receivedUnits: units(item.receivedKg, false),
        unitPriceCents: price,
        invoiceNumber: invoice,
        status: 'pending',
        lossUnits: null,
        allocations: participants.map((school) => ({
          school,
          requestedUnits: 0,
          allocatedUnits: 0,
        })),
      };
    }),
  };
}
export function saveAllocation(batch: Batch, itemId: string, input: SaveAllocation): Batch {
  if (input.revision !== batch.revision)
    throw new DomainError(
      'REVISION_CONFLICT',
      'O montante foi atualizado. Recarregue antes de salvar.',
      409,
    );
  const item = batch.items.find((item) => item.id === itemId);
  if (!item)
    throw new DomainError('ITEM_NOT_FOUND', 'Alimento não encontrado neste montante.', 404);
  const requested = new Map<string, number>();
  for (const request of input.requests) {
    if (!batch.participatingSchools.includes(request.school) || requested.has(request.school)) {
      throw new DomainError(
        'INVALID_SCHOOL_REQUEST',
        'Informe apenas escolas participantes, sem repetições.',
      );
    }
    requested.set(request.school, units(request.requestedKg));
  }
  const allocated = [...requested.values()].reduce((sum, quantity) => sum + quantity, 0);
  if (allocated > item.receivedUnits)
    throw new DomainError('STOCK_EXCEEDED', 'A soma dos pedidos não pode ultrapassar o recebido.');
  const remainder = item.receivedUnits - allocated;
  if (remainder > 0 && (input.remainderConfirmed !== true || input.lossKg === undefined)) {
    throw new DomainError(
      'BALANCE_CONFIRMATION_REQUIRED',
      'Confirme e classifique o saldo como sobra aproveitável ou perda.',
    );
  }
  const loss = units(input.lossKg ?? 0);
  if (loss > remainder)
    throw new DomainError('INVALID_LOSS', 'A perda não pode ultrapassar o saldo.');
  return {
    ...batch,
    revision: batch.revision + 1,
    updatedAt: new Date().toISOString(),
    items: batch.items.map((current) =>
      current.id !== itemId
        ? current
        : {
            ...current,
            status: 'completed',
            lossUnits: loss,
            allocations: batch.participatingSchools.map((school) => ({
              school,
              requestedUnits: requested.get(school) ?? 0,
              allocatedUnits: requested.get(school) ?? 0,
            })),
          },
    ),
  };
}
export function itemQuantities(item: Item) {
  const distributed =
    item.status === 'completed'
      ? item.allocations.reduce((sum, allocation) => sum + allocation.allocatedUnits, 0)
      : 0;
  const pending = item.status === 'pending' ? item.receivedUnits : 0;
  const loss = item.status === 'completed' ? (item.lossUnits ?? 0) : 0;
  const unclassified =
    item.status === 'completed' && item.lossUnits === null ? item.receivedUnits - distributed : 0;
  const surplus =
    item.status === 'completed' && item.lossUnits !== null
      ? item.receivedUnits - distributed - loss
      : 0;
  return { distributed, surplus, loss, pending, unclassified };
}
export function batchDto(batch: Batch) {
  return {
    ...batch,
    status: batch.items.every((item) => item.status === 'completed') ? 'completed' : 'pending',
    items: batch.items.map(({ receivedUnits, lossUnits, allocations, ...item }) => {
      const quantities = itemQuantities({ ...item, receivedUnits, lossUnits, allocations });
      return {
        ...item,
        receivedKg: receivedUnits / 10,
        lossKg: lossUnits === null ? null : lossUnits / 10,
        distributedKg: quantities.distributed / 10,
        surplusKg: quantities.surplus / 10,
        allocations: allocations.map(({ school, requestedUnits, allocatedUnits }) => ({
          school,
          requestedKg: requestedUnits / 10,
          allocatedKg: allocatedUnits / 10,
        })),
      };
    }),
  };
}
