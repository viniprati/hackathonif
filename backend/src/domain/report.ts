import { DomainError, itemQuantities, validDate, type Batch } from './batch.js';

export function reportWindow(period: 'week' | 'month', reference: string) {
  validDate(reference);
  const start = new Date(`${reference}T00:00:00.000Z`);
  if (period === 'month') start.setUTCDate(1);
  else start.setUTCDate(start.getUTCDate() - ((start.getUTCDay() + 6) % 7));
  const end = new Date(start);
  if (period === 'month') end.setUTCMonth(end.getUTCMonth() + 1);
  else end.setUTCDate(end.getUTCDate() + 7);
  const last = new Date(end);
  last.setUTCDate(last.getUTCDate() - 1);
  return {
    start: start.toISOString().slice(0, 10),
    endExclusive: end.toISOString().slice(0, 10),
    lastDay: last.toISOString().slice(0, 10),
  };
}
interface Totals {
  receivedUnits: number;
  distributedUnits: number;
  surplusUnits: number;
  lossUnits: number;
  pendingUnits: number;
  unclassifiedUnits: number;
  receivedCents: number;
  distributedCents: number;
  surplusCents: number;
  lossCents: number;
  pendingCents: number;
  unclassifiedCents: number;
  unpricedCount: number;
}
function empty(): Totals {
  return {
    receivedUnits: 0,
    distributedUnits: 0,
    surplusUnits: 0,
    lossUnits: 0,
    pendingUnits: 0,
    unclassifiedUnits: 0,
    receivedCents: 0,
    distributedCents: 0,
    surplusCents: 0,
    lossCents: 0,
    pendingCents: 0,
    unclassifiedCents: 0,
    unpricedCount: 0,
  };
}
function split(total: number, weights: number[]) {
  const sum = weights.reduce((a, b) => a + b, 0);
  if (!sum) return weights.map(() => 0);
  // Integer arithmetic avoids rounding drift for large cent values.
  const denominator = BigInt(sum);
  const numerators = weights.map((weight) => BigInt(total) * BigInt(weight));
  const values = numerators.map((value) => Number(value / denominator));
  const order = numerators
    .map((value, index) => ({ index, rest: value % denominator }))
    .sort((a, b) => (a.rest === b.rest ? a.index - b.index : a.rest > b.rest ? -1 : 1));
  let remainder = total - values.reduce((a, b) => a + b, 0);
  for (const { index } of order) {
    if (remainder-- <= 0) break;
    values[index] = values[index]! + 1;
  }
  return values;
}
function dto(total: Totals) {
  const {
    receivedUnits,
    distributedUnits,
    surplusUnits,
    lossUnits,
    pendingUnits,
    unclassifiedUnits,
    ...money
  } = total;
  return {
    ...money,
    receivedKg: receivedUnits / 10,
    distributedKg: distributedUnits / 10,
    surplusKg: surplusUnits / 10,
    lossKg: lossUnits / 10,
    pendingKg: pendingUnits / 10,
    unclassifiedKg: unclassifiedUnits / 10,
    lossRate: receivedUnits === 0 ? 0 : lossUnits / receivedUnits,
  };
}
export function stockReport(batches: Batch[], period: 'week' | 'month', reference: string) {
  const window = reportWindow(period, reference);
  const foods = new Map<string, Totals>();
  const schoolTotals = new Map<string, { school: string; units: number; valueCents: number }>();
  const foodSchools = new Map<
    string,
    Map<string, { school: string; units: number; valueCents: number }>
  >();
  for (const batch of batches) {
    if (batch.date < window.start || batch.date >= window.endExclusive) continue;
    for (const item of batch.items) {
      const quantity = itemQuantities(item);
      const cost =
        item.unitPriceCents === null
          ? 0
          : Number((BigInt(item.receivedUnits) * BigInt(item.unitPriceCents) + 5n) / 10n);
      const values = split(cost, [
        quantity.distributed,
        quantity.surplus,
        quantity.loss,
        quantity.pending,
        quantity.unclassified,
      ]);
      const total = foods.get(item.product) ?? empty();
      total.receivedUnits += item.receivedUnits;
      total.receivedCents += cost;
      total.distributedUnits += quantity.distributed;
      total.distributedCents += values[0]!;
      total.surplusUnits += quantity.surplus;
      total.surplusCents += values[1]!;
      total.lossUnits += quantity.loss;
      total.lossCents += values[2]!;
      total.pendingUnits += quantity.pending;
      total.pendingCents += values[3]!;
      total.unclassifiedUnits += quantity.unclassified;
      total.unclassifiedCents += values[4]!;
      if (item.unitPriceCents === null) total.unpricedCount++;
      foods.set(item.product, total);
      if (item.status !== 'completed') continue;
      const allocations = split(
        values[0]!,
        item.allocations.map((allocation) => allocation.allocatedUnits),
      );
      const participants =
        foodSchools.get(item.product) ??
        new Map<string, { school: string; units: number; valueCents: number }>();
      item.allocations.forEach((allocation, index) => {
        if (!allocation.allocatedUnits) return;
        for (const group of [schoolTotals, participants]) {
          const school = group.get(allocation.school) ?? {
            school: allocation.school,
            units: 0,
            valueCents: 0,
          };
          school.units += allocation.allocatedUnits;
          school.valueCents += allocations[index]!;
          group.set(allocation.school, school);
        }
      });
      foodSchools.set(item.product, participants);
    }
  }
  const total = empty();
  for (const food of foods.values()) {
    for (const key of Object.keys(total) as (keyof Totals)[]) {
      total[key] += food[key];
      if (!Number.isSafeInteger(total[key]))
        throw new DomainError(
          'REPORT_LIMIT',
          'O volume financeiro excede o limite deste relatório. Escolha um período menor.',
        );
    }
  }
  const schoolDto = (group: Map<string, { school: string; units: number; valueCents: number }>) =>
    [...group.values()]
      .sort((a, b) => a.school.localeCompare(b.school, 'pt-BR'))
      .map(({ units, ...school }) => ({ ...school, kg: units / 10 }));
  return {
    period,
    window,
    totals: dto(total),
    foods: [...foods]
      .sort(([a], [b]) => a.localeCompare(b, 'pt-BR'))
      .map(([name, totals]) => ({
        name,
        ...dto(totals),
        schools: schoolDto(foodSchools.get(name) ?? new Map()),
      })),
    schools: schoolDto(schoolTotals),
  };
}
