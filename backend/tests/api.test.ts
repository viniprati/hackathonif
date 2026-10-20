import assert from 'node:assert/strict';
import test from 'node:test';
import { buildApp } from '../src/app.js';
import { schools } from '../src/domain/catalog.js';
import { MemoryRepository, input, credentials } from './support.js';

async function authorize(app: Awaited<ReturnType<typeof buildApp>>) {
  const login = await app.inject({
    method: 'POST',
    url: '/v1/auth/login',
    payload: { cpf: credentials.mvpCpf, password: credentials.mvpPassword },
  });
  assert.equal(login.statusCode, 200);
  return { authorization: `Bearer ${login.json().accessToken}` };
}
test('rotas de negócio exigem autenticação e não expõem o corpo inválido', async (t) => {
  const app = await buildApp({ repository: new MemoryRepository(), ...credentials, logger: false });
  t.after(() => app.close());
  const headers = await authorize(app);
  assert.equal((await app.inject('/health/live')).statusCode, 200);
  assert.equal((await app.inject('/v1/catalog/foods')).statusCode, 401);
  const response = await app.inject({ url: '/v1/catalog/foods', headers });
  assert.equal(response.statusCode, 200);
  assert.equal(response.json().foods.length, 10);
  assert.equal(typeof response.headers['x-request-id'], 'string');
  const missing = await app.inject('/not-a-route');
  assert.equal(missing.statusCode, 404);
  assert.equal(missing.json().requestId, missing.headers['x-request-id']);
  const invalid = await app.inject({
    method: 'POST',
    url: '/v1/batches',
    headers,
    payload: { ...input, secret: 'must-not-be-echoed' },
  });
  assert.equal(invalid.statusCode, 400);
  assert.ok(!invalid.body.includes('must-not-be-echoed'));
});
test('API cadastra, filtra, salva com revisão e consolida por alimento', async (t) => {
  const repository = new MemoryRepository();
  const app = await buildApp({ repository, ...credentials, logger: false });
  t.after(() => app.close());
  const headers = await authorize(app);
  const created = await app.inject({ method: 'POST', url: '/v1/batches', headers, payload: input });
  assert.equal(created.statusCode, 201);
  const batch = created.json();
  assert.equal(batch.revision, 0);
  assert.ok(!('receivedUnits' in batch.items[0]));
  const url = `/v1/batches/${batch.id}/items/${batch.items[0].id}/allocation`;
  const tooMuch = await app.inject({
    method: 'PUT',
    url,
    headers,
    payload: { revision: 0, requests: [{ school: 'IFES', requestedKg: 100.1 }] },
  });
  assert.equal(tooMuch.statusCode, 422);
  assert.equal(tooMuch.json().error.code, 'STOCK_EXCEEDED');
  const saved = await app.inject({
    method: 'PUT',
    url,
    headers,
    payload: {
      revision: 0,
      requests: [{ school: 'IFES', requestedKg: 60 }],
      remainderConfirmed: true,
      lossKg: 10,
    },
  });
  assert.equal(saved.statusCode, 200);
  assert.equal(saved.json().items[0].lossKg, 10);
  assert.equal(saved.json().items[0].surplusKg, 30);
  const stale = await app.inject({
    method: 'PUT',
    url,
    headers,
    payload: { revision: 0, requests: [{ school: 'IFES', requestedKg: 100 }] },
  });
  assert.equal(stale.statusCode, 409);
  const read = await app.inject({ url: `/v1/batches/${batch.id}`, headers });
  assert.equal(read.json().revision, 1);
  const list = await app.inject({
    url: '/v1/batches?status=completed&from=2026-10-01&to=2026-10-31&limit=1',
    headers,
  });
  assert.equal(list.statusCode, 200);
  assert.equal(list.json().total, 1);
  const report = await app.inject({
    url: '/v1/reports/foods?period=month&reference=2026-10-19',
    headers,
  });
  assert.equal(report.statusCode, 200);
  assert.equal(report.json().foods[0].distributedKg, 60);
});
test('valida tipos sem conversão silenciosa e aceita passo decimal de 0,1 kg', async (t) => {
  const app = await buildApp({ repository: new MemoryRepository(), ...credentials, logger: false });
  t.after(() => app.close());
  const headers = await authorize(app);
  for (const receivedKg of ['10', 0.05, -1]) {
    const response = await app.inject({
      method: 'POST',
      url: '/v1/batches',
      headers,
      payload: { ...input, items: [{ product: 'Aipim', receivedKg }] },
    });
    assert.equal(response.statusCode, 400);
  }
  const accepted = await app.inject({
    method: 'POST',
    url: '/v1/batches',
    headers,
    payload: { ...input, items: [{ product: 'Aipim', receivedKg: 0.3 }] },
  });
  assert.equal(accepted.statusCode, 201);
  const injection = await app.inject({ url: '/v1/batches?status[$ne]=pending', headers });
  assert.equal(injection.statusCode, 400);
  const wrongDate = await app.inject({ url: '/v1/batches?from=2026-02-30', headers });
  assert.equal(wrongDate.statusCode, 422);
});
test('conflito entre gravações concorrentes é informado em vez de perder alteração', async (t) => {
  class ConcurrentRepository extends MemoryRepository {
    override async replace() {
      return false;
    }
  }
  const app = await buildApp({
    repository: new ConcurrentRepository(),
    ...credentials,
    logger: false,
  });
  t.after(() => app.close());
  const headers = await authorize(app);
  const batch = (
    await app.inject({ method: 'POST', url: '/v1/batches', headers, payload: input })
  ).json();
  const result = await app.inject({
    method: 'PUT',
    url: `/v1/batches/${batch.id}/items/${batch.items[0].id}/allocation`,
    headers,
    payload: { revision: 0, requests: [{ school: 'IFES', requestedKg: 100 }] },
  });
  assert.equal(result.statusCode, 409);
});
test('readiness retorna 503 quando o MongoDB não está disponível', async (t) => {
  const app = await buildApp({
    repository: new MemoryRepository(),
    ...credentials,
    logger: false,
    ping: async () => {
      throw new Error('secret-uri');
    },
  });
  t.after(() => app.close());
  const headers = await authorize(app);
  const response = await app.inject('/health/ready');
  assert.equal(response.statusCode, 503);
  assert.ok(!response.body.includes('secret-uri'));
});

test('API lista 13 escolas e aceita uma nova EMEF no cadastro e rateio', async (t) => {
  const app = await buildApp({ repository: new MemoryRepository(), ...credentials, logger: false });
  t.after(() => app.close());
  const headers = await authorize(app);
  const catalog = await app.inject({ url: '/v1/catalog/schools', headers });
  assert.equal(catalog.statusCode, 200);
  assert.deepEqual(catalog.json().schools, [...schools]);
  assert.equal(catalog.json().schools.length, 13);
  const school = schools[schools.length - 1]!;
  const created = await app.inject({
    method: 'POST',
    url: '/v1/batches',
    headers,
    payload: { ...input, participatingSchools: [school] },
  });
  assert.equal(created.statusCode, 201);
  const batch = created.json();
  const saved = await app.inject({
    method: 'PUT',
    url: `/v1/batches/${batch.id}/items/${batch.items[0].id}/allocation`,
    headers,
    payload: { revision: 0, requests: [{ school, requestedKg: 100 }] },
  });
  assert.equal(saved.statusCode, 200);
  assert.deepEqual(saved.json().participatingSchools, [school]);
  assert.equal(saved.json().items[0].distributedKg, 100);
});
