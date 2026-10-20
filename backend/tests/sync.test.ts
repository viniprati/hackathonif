import assert from 'node:assert/strict';
import test from 'node:test';
import { randomUUID } from 'node:crypto';
import { buildApp } from '../src/app.js';
import { MemoryRepository, credentials, input } from './support.js';

const snapshot = {
  ...input,
  revision: null,
  items: [
    {
      ...input.items[0]!,
      status: 'completed',
      requests: [{ school: 'IFES', requestedKg: 60 }],
      lossKg: 10,
    },
  ],
};
async function setup() {
  const repository = new MemoryRepository();
  const app = await buildApp({ repository, ...credentials, logger: false });
  const login = await app.inject({
    method: 'POST',
    url: '/v1/auth/login',
    payload: { cpf: credentials.mvpCpf, password: credentials.mvpPassword },
  });
  const headers = { authorization: `Bearer ${login.json().accessToken}` };
  return { repository, app, headers };
}

test('sincronização atômica: criação, reenvio idempotente, revisão e conflito', async (t) => {
  const { repository, app, headers } = await setup();
  t.after(() => app.close());
  const url = `/v1/batches/${randomUUID()}/sync`;
  const created = await app.inject({ method: 'PUT', url, headers, payload: snapshot });
  assert.equal(created.statusCode, 201);
  assert.equal(created.json().revision, 0);
  assert.equal(created.json().items[0].distributedKg, 60);
  assert.equal(created.json().items[0].surplusKg, 30);
  assert.equal(created.json().items[0].lossKg, 10);
  const retry = await app.inject({ method: 'PUT', url, headers, payload: snapshot });
  assert.equal(retry.statusCode, 200);
  assert.deepEqual(retry.json(), created.json());
  assert.equal(await repository.count({}), 1);
  const next = {
    ...snapshot,
    revision: 0,
    items: [{ ...snapshot.items[0]!, requests: [{ school: 'IFES', requestedKg: 50 }], lossKg: 5 }],
  };
  const updated = await app.inject({ method: 'PUT', url, headers, payload: next });
  assert.equal(updated.statusCode, 200);
  assert.equal(updated.json().revision, 1);
  assert.equal(updated.json().items[0].id, created.json().items[0].id);
  const conflict = await app.inject({
    method: 'PUT',
    url,
    headers,
    payload: { ...next, items: snapshot.items },
  });
  assert.equal(conflict.statusCode, 409);
  const retriedUpdate = await app.inject({ method: 'PUT', url, headers, payload: next });
  assert.equal(retriedUpdate.statusCode, 200);
  assert.deepEqual(retriedUpdate.json(), updated.json());
  const read = await app.inject({ url: `/v1/batches/${created.json().id}`, headers });
  assert.deepEqual(read.json(), updated.json());
});

test('valida o montante inteiro antes de gravar; não aceita valores inválidos ou perda não classificada', async (t) => {
  const { repository, app, headers } = await setup();
  t.after(() => app.close());
  for (const [item, status] of [
    [{ ...snapshot.items[0]!, receivedKg: -1 }, 400],
    [{ ...snapshot.items[0]!, requests: [{ school: 'IFES', requestedKg: 101 }] }, 422],
    [{ ...snapshot.items[0]!, lossKg: 41 }, 422],
    [{ ...snapshot.items[0]!, lossKg: null }, 422],
    [{ ...snapshot.items[0]!, status: 'pending', requests: [], lossKg: 0 }, 422],
    [
      {
        ...snapshot.items[0]!,
        status: 'pending',
        requests: [{ school: 'Pinto Coelho', requestedKg: 0 }],
        lossKg: null,
      },
      422,
    ],
    [
      {
        ...snapshot.items[0]!,
        status: 'pending',
        requests: [
          { school: 'IFES', requestedKg: 0 },
          { school: 'IFES', requestedKg: 0 },
        ],
        lossKg: null,
      },
      422,
    ],
  ] as const) {
    const result = await app.inject({
      method: 'PUT',
      url: `/v1/batches/${randomUUID()}/sync`,
      headers,
      payload: { ...snapshot, items: [{ ...snapshot.items[0]!, product: 'Chuchu' }, item] },
    });
    assert.equal(result.statusCode, status);
    assert.equal(await repository.count({}), 0);
  }
});

test('criações concorrentes com a mesma chave não duplicam e remoção não recria com revisão antiga', async (t) => {
  const { repository, app, headers } = await setup();
  t.after(() => app.close());
  const url = `/v1/batches/${randomUUID()}/sync`;
  const results = await Promise.all(
    [1, 2].map(() => app.inject({ method: 'PUT', url, headers, payload: snapshot })),
  );
  assert.deepEqual(results.map((response) => response.statusCode).sort(), [200, 201]);
  assert.equal(await repository.count({}), 1);
  const missing = await app.inject({
    method: 'PUT',
    url: `/v1/batches/${randomUUID()}/sync`,
    headers,
    payload: { ...snapshot, revision: 2 },
  });
  assert.equal(missing.statusCode, 409);
  assert.equal((await app.inject({ method: 'PUT', url, payload: snapshot })).statusCode, 401);
});

test('CORS autoriza PUT de sincronização apenas na origem configurada', async (t) => {
  const app = await buildApp({
    repository: new MemoryRepository(),
    ...credentials,
    logger: false,
    origins: ['https://demo.example.test'],
  });
  t.after(() => app.close());
  const headers = {
    origin: 'https://demo.example.test',
    'access-control-request-method': 'PUT',
    'access-control-request-headers': 'authorization,content-type',
  };
  const allowed = await app.inject({
    method: 'OPTIONS',
    url: `/v1/batches/${randomUUID()}/sync`,
    headers,
  });
  assert.equal(allowed.statusCode, 204);
  assert.equal(allowed.headers['access-control-allow-origin'], headers.origin);
  assert.ok(String(allowed.headers['access-control-allow-methods']).includes('PUT'));
  const denied = await app.inject({
    method: 'OPTIONS',
    url: '/v1/batches',
    headers: { ...headers, origin: 'https://untrusted.example.test' },
  });
  assert.equal(denied.headers['access-control-allow-origin'], undefined);
});
