import assert from 'node:assert/strict';
import test from 'node:test';
import { MongoMemoryServer } from 'mongodb-memory-server-core';
import { MongoClient } from 'mongodb';
import { buildApp } from '../../src/app.js';
import { MongoBatchRepository } from '../../src/repositories/batch-repository.js';
import { credentials, input } from '../support.js';

test(
  'fluxo HTTP isolado: validações, saldo e persistência após reiniciar API e conexão',
  { timeout: 120000 },
  async (t) => {
    const mongod = await MongoMemoryServer.create();
    t.after(() => mongod.stop());
    async function session() {
      const client = await new MongoClient(mongod.getUri()).connect();
      const db = client.db('nativa_demo_flow_test');
      const repository = new MongoBatchRepository(db);
      await repository.initialize();
      const app = await buildApp({
        repository,
        ...credentials,
        logger: false,
        origins: ['https://demo.example.test'],
        ping: async () => {
          await db.command({ ping: 1 });
        },
      });
      app.addHook('onClose', async () => {
        await client.close();
      });
      t.after(() => app.close());
      const base = await app.listen({ host: '127.0.0.1', port: 0 });
      async function request(path: string, method = 'GET', payload?: unknown, token?: string) {
        const response = await fetch(`${base}${path}`, {
          method,
          headers: {
            ...(payload ? { 'content-type': 'application/json' } : {}),
            ...(token ? { authorization: `Bearer ${token}` } : {}),
          },
          ...(payload ? { body: JSON.stringify(payload) } : {}),
        });
        return { status: response.status, body: await response.json() };
      }
      const login = await request('/v1/auth/login', 'POST', {
        cpf: credentials.mvpCpf,
        password: credentials.mvpPassword,
      });
      assert.equal(login.status, 200);
      return { app, request, token: login.body.accessToken as string, base };
    }
    const first = await session();
    assert.equal((await first.request('/health/live')).status, 200);
    assert.equal((await first.request('/health/ready')).status, 200);
    assert.equal((await first.request('/v1/batches')).status, 401);
    assert.equal((await first.request('/v1/batches', 'GET', undefined, 'invalid')).status, 401);
    assert.equal(
      (
        await first.request('/v1/auth/login', 'POST', {
          cpf: credentials.mvpCpf,
          password: 'invalid',
        })
      ).status,
      401,
    );
    const preflight = await fetch(`${first.base}/v1/batches`, {
      method: 'OPTIONS',
      headers: {
        origin: 'https://demo.example.test',
        'access-control-request-method': 'POST',
        'access-control-request-headers': 'authorization,content-type',
      },
    });
    assert.equal(preflight.status, 204);
    assert.equal(preflight.headers.get('access-control-allow-origin'), 'https://demo.example.test');
    const badCreate = await first.request(
      '/v1/batches',
      'POST',
      { ...input, items: [{ product: 'Aipim', receivedKg: -1 }] },
      first.token,
    );
    assert.equal(badCreate.status, 400);
    const created = await first.request('/v1/batches', 'POST', input, first.token);
    assert.equal(created.status, 201);
    const batch = created.body;
    const path = `/v1/batches/${batch.id}`;
    const allocationPath = `${path}/items/${batch.items[0].id}/allocation`;
    assert.equal((await first.request(path, 'GET', undefined, first.token)).status, 200);
    const cases = [
      { requests: [{ school: 'IFES', requestedKg: -1 }], status: 400 },
      {
        requests: [
          { school: 'IFES', requestedKg: 60 },
          { school: 'Darllin', requestedKg: 50 },
        ],
        status: 422,
        code: 'STOCK_EXCEEDED',
      },
      {
        requests: [{ school: 'IFES', requestedKg: 60 }],
        status: 422,
        code: 'BALANCE_CONFIRMATION_REQUIRED',
      },
      {
        requests: [{ school: 'IFES', requestedKg: 60 }],
        remainderConfirmed: true,
        lossKg: -1,
        status: 400,
      },
      {
        requests: [{ school: 'IFES', requestedKg: 60 }],
        remainderConfirmed: true,
        lossKg: 41,
        status: 422,
        code: 'INVALID_LOSS',
      },
    ];
    for (const { status, code, ...payload } of cases) {
      const result = await first.request(
        allocationPath,
        'PUT',
        { revision: 0, ...payload },
        first.token,
      );
      assert.equal(result.status, status);
      if (code) assert.equal(result.body.error.code, code);
      const unchanged = await first.request(path, 'GET', undefined, first.token);
      assert.equal(unchanged.body.revision, 0);
      assert.equal(unchanged.body.items[0].status, 'pending');
    }
    const saved = await first.request(
      allocationPath,
      'PUT',
      {
        revision: 0,
        requests: [{ school: 'IFES', requestedKg: 60 }],
        remainderConfirmed: true,
        lossKg: 10,
      },
      first.token,
    );
    assert.equal(saved.status, 200);
    assert.equal(saved.body.items[0].distributedKg, 60);
    assert.equal(saved.body.items[0].surplusKg, 30);
    assert.equal(saved.body.items[0].lossKg, 10);
    assert.equal(saved.body.items[0].status, 'completed');
    await first.app.close();
    const second = await session();
    assert.notEqual(second.token, first.token);
    const persisted = await second.request(path, 'GET', undefined, second.token);
    assert.equal(persisted.status, 200);
    assert.deepEqual(persisted.body, saved.body);
    const report = await second.request(
      '/v1/reports/foods?period=month&reference=2026-10-15',
      'GET',
      undefined,
      second.token,
    );
    assert.equal(report.status, 200);
    assert.equal(report.body.totals.receivedKg, 100);
    assert.equal(report.body.totals.distributedKg, 60);
    assert.equal(report.body.totals.lossKg, 10);
    assert.equal(report.body.totals.surplusKg, 30);
  },
);
