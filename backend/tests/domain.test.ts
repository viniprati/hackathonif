import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import { createBatch, saveAllocation, units } from '../src/domain/batch.js';
import { foods, invoices } from '../src/domain/catalog.js';
import { reportWindow, stockReport } from '../src/domain/report.js';
import { input } from './support.js';

test('catálogo fechado contém os mesmos alimentos e notas do Flutter', async () => {
  const flutter = await readFile(new URL('../../lib/domain/catalog.dart', import.meta.url), 'utf8');
  const flutterNames = [...flutter.matchAll(/FoodCatalogItem\('([^']+)'/g)].map(
    (match) => match[1],
  );
  assert.deepEqual(
    foods.map((food) => food.name),
    flutterNames,
  );
  assert.equal(foods.length, 10);
  for (const invoice of invoices)
    assert.equal(
      invoice.items.reduce((sum, item) => sum + item.totalCents, 0),
      invoice.totalCents,
    );
});
test('seleção de escolas é obrigatória e vale para todos os alimentos', () => {
  assert.throws(() => createBatch({ ...input, participatingSchools: [] }));
  assert.throws(() => createBatch({ ...input, participatingSchools: ['IFES', 'IFES'] }));
  assert.throws(() => createBatch({ ...input, participatingSchools: ['Inventada'] }));
  const batch = createBatch({
    ...input,
    items: [...input.items, { product: 'Chuchu', receivedKg: 20, unitPriceCents: 426 }],
  });
  assert.equal(batch.items.length, 2);
  for (const item of batch.items)
    assert.deepEqual(
      item.allocations.map((allocation) => allocation.school),
      ['IFES', 'Darllin'],
    );
});
test('valida alimento, data real, quantidade e vínculo da nota', () => {
  for (const date of ['2026-02-30', '2026-13-01', '2026-10-15T10:00:00Z'])
    assert.throws(() => createBatch({ ...input, date }));
  for (const value of [NaN, Infinity, -0.1, 0.05, 1000000.1]) assert.throws(() => units(value));
  for (const value of [0, 0.1, 0.3, 1000000]) assert.equal(units(value), Math.round(value * 10));
  assert.throws(() => createBatch({ ...input, items: [{ product: 'Inventado', receivedKg: 10 }] }));
  assert.throws(() => createBatch({ ...input, items: [input.items[0]!, input.items[0]!] }));
  assert.throws(() =>
    createBatch({
      ...input,
      items: [{ ...input.items[0]!, invoiceNumber: '190720001', unitPriceCents: 100 }],
    }),
  );
  assert.doesNotThrow(() =>
    createBatch({ ...input, items: [{ ...input.items[0]!, invoiceNumber: '190720001' }] }),
  );
});
test('bloqueia excesso, escola não participante, duplicatas e revisão antiga', () => {
  const batch = createBatch(input);
  const id = batch.items[0]!.id;
  assert.throws(() =>
    saveAllocation(batch, id, { revision: 0, requests: [{ school: 'IFES', requestedKg: 100.1 }] }),
  );
  assert.throws(() =>
    saveAllocation(batch, id, {
      revision: 0,
      requests: [{ school: 'Pinto Coelho', requestedKg: 0 }],
    }),
  );
  assert.throws(() =>
    saveAllocation(batch, id, {
      revision: 0,
      requests: [
        { school: 'IFES', requestedKg: 50 },
        { school: 'IFES', requestedKg: 50 },
      ],
    }),
  );
  assert.throws(() => saveAllocation(batch, id, { revision: 2, requests: [] }));
  assert.equal(batch.revision, 0);
  assert.equal(batch.items[0]!.status, 'pending');
  const saved = saveAllocation(batch, id, {
    revision: 0,
    requests: [{ school: 'IFES', requestedKg: 100 }],
  });
  assert.equal(saved.revision, 1);
  assert.deepEqual(saved.participatingSchools, batch.participatingSchools);
  assert.equal(saved.items[0]!.allocations[1]!.requestedUnits, 0);
});
test('exige confirmar o saldo e aceita perda parcial até o saldo disponível', () => {
  const batch = createBatch(input);
  const id = batch.items[0]!.id;
  const request = { revision: 0, requests: [{ school: 'IFES', requestedKg: 60 }] };
  assert.throws(() => saveAllocation(batch, id, request));
  assert.throws(() => saveAllocation(batch, id, { ...request, remainderConfirmed: true }));
  assert.throws(() =>
    saveAllocation(batch, id, { ...request, remainderConfirmed: true, lossKg: 40.1 }),
  );
  const saved = saveAllocation(batch, id, { ...request, remainderConfirmed: true, lossKg: 10 });
  assert.equal(saved.items[0]!.lossUnits, 100);
  const report = stockReport([saved], 'month', '2026-10-19');
  assert.equal(report.totals.receivedKg, 100);
  assert.equal(report.totals.distributedKg, 60);
  assert.equal(report.totals.surplusKg, 30);
  assert.equal(report.totals.lossKg, 10);
  assert.equal(report.totals.lossRate, 0.1);
});
test('relatório consolida alimentos a preços diferentes e não transforma pendência em perda', () => {
  const first = createBatch(input);
  const saved = saveAllocation(first, first.items[0]!.id, {
    revision: 0,
    requests: [{ school: 'IFES', requestedKg: 60 }],
    remainderConfirmed: true,
    lossKg: 10,
  });
  const second = createBatch({
    ...input,
    items: [{ product: 'Aipim', receivedKg: 20, unitPriceCents: 300 }],
  });
  const unpriced = createBatch({ ...input, items: [{ product: 'Aipim', receivedKg: 10 }] });
  const previous = createBatch({ ...input, date: '2026-09-15' });
  const report = stockReport([saved, second, unpriced, previous], 'month', '2026-10-19');
  assert.equal(report.foods.length, 1);
  assert.equal(report.totals.receivedKg, 130);
  assert.equal(report.totals.receivedCents, 63200);
  assert.equal(report.totals.unpricedCount, 1);
  assert.equal(report.totals.pendingKg, 30);
  assert.equal(report.totals.lossKg, 10);
  const total = report.totals;
  assert.equal(
    total.receivedCents,
    total.distributedCents +
      total.surplusCents +
      total.lossCents +
      total.pendingCents +
      total.unclassifiedCents,
  );
  assert.equal(
    total.receivedKg,
    total.distributedKg + total.surplusKg + total.lossKg + total.pendingKg + total.unclassifiedKg,
  );
  assert.equal(report.schools[0]!.valueCents, total.distributedCents);
  assert.equal(report.foods[0]!.schools[0]!.kg, 60);
});
test('centavos são conservados com quantidades fracionárias e preço ímpar', () => {
  const batch = createBatch({
    ...input,
    items: [{ product: 'Aipim', receivedKg: 0.3, unitPriceCents: 103 }],
  });
  const saved = saveAllocation(batch, batch.items[0]!.id, {
    revision: 0,
    requests: [{ school: 'IFES', requestedKg: 0.1 }],
    remainderConfirmed: true,
    lossKg: 0.1,
  });
  const report = stockReport([saved], 'month', input.date);
  const totals = report.totals;
  assert.equal(totals.receivedCents, 31);
  assert.equal(totals.distributedCents + totals.surplusCents + totals.lossCents, 31);
});
test('semanas, ano bissexto e relatório vazio', () => {
  assert.deepEqual(reportWindow('week', '2027-01-01'), {
    start: '2026-12-28',
    endExclusive: '2027-01-04',
    lastDay: '2027-01-03',
  });
  assert.equal(reportWindow('month', '2028-02-10').lastDay, '2028-02-29');
  const empty = stockReport([], 'month', input.date);
  assert.equal(empty.totals.lossRate, 0);
  assert.deepEqual(empty.foods, []);
});
