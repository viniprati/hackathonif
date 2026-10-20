import assert from 'node:assert/strict';
import test from 'node:test';
import { MongoMemoryServer } from 'mongodb-memory-server-core';
import { MongoClient } from 'mongodb';
import { createBatch, saveAllocation } from '../../src/domain/batch.js';
import { MongoBatchRepository } from '../../src/repositories/batch-repository.js';
import { buildApp } from '../../src/app.js';
import { credentials, input } from '../support.js';

test(
  'MongoDB real local: persistência, filtros, concorrência e API com JWT',
  { timeout: 120000 },
  async (t) => {
    const mongod = await MongoMemoryServer.create();
    t.after(() => mongod.stop());
    const client = new MongoClient(mongod.getUri());
    t.after(() => client.close());
    await client.connect();
    const db = client.db('nativa_integration');
    const repository = new MongoBatchRepository(db);
    await repository.initialize();
    const batch = createBatch(input);
    await repository.insert(batch);
    assert.deepEqual(await new MongoBatchRepository(db).get(batch.id), batch);
    assert.equal(
      await repository.count({ from: '2026-10-01', toExclusive: '2026-11-01', status: 'pending' }),
      1,
    );
    assert.equal((await repository.list({ from: '2026-11-01' }, 0, 20)).length, 0);
    const first = saveAllocation(batch, batch.items[0]!.id, {
      revision: 0,
      requests: [{ school: 'IFES', requestedKg: 100 }],
    });
    const second = saveAllocation(batch, batch.items[0]!.id, {
      revision: 0,
      requests: [{ school: 'Darllin', requestedKg: 100 }],
    });
    const results = await Promise.all([
      repository.replace(first, 0),
      repository.replace(second, 0),
    ]);
    assert.equal(results.filter(Boolean).length, 1);
    assert.equal((await repository.get(batch.id))!.revision, 1);
    assert.equal(await repository.count({ status: 'completed' }), 1);
    const app = await buildApp({
      repository,
      ...credentials,
      logger: false,
      ping: async () => {
        await db.command({ ping: 1 });
      },
    });
    t.after(() => app.close());
    const login = await app.inject({
      method: 'POST',
      url: '/v1/auth/login',
      payload: { cpf: credentials.mvpCpf, password: credentials.mvpPassword },
    });
    assert.equal(login.statusCode, 200);
    const headers = { authorization: `Bearer ${login.json().accessToken}` };
    const response = await app.inject({
      url: '/v1/reports/foods?period=month&reference=2026-10-15',
      headers,
    });
    assert.equal(response.statusCode, 200);
    assert.equal(response.json().totals.distributedKg, 100);
    const ready = await app.inject('/health/ready');
    assert.equal(ready.statusCode, 200);
  },
);
