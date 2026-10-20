import assert from 'node:assert/strict';
import test from 'node:test';
import { buildApp } from '../src/app.js';
import { createBatch, saveAllocation } from '../src/domain/batch.js';
import { batchNotifications } from '../src/domain/notifications.js';
import { dispatchPush } from '../src/push.js';
import { MemoryRepository, credentials, input } from './support.js';

test('avisos: criação, conclusão somente de todos os alimentos e sem duplicar revisão concluída', async () => {
  const repo = new MemoryRepository();
  const batch = createBatch({
    ...input,
    items: [...input.items, { product: 'Tomate', receivedKg: 10 }],
  });
  await repo.insertIfAbsent(batch);
  await repo.insertIfAbsent(batch);
  assert.equal((await repo.notifications(0, 50)).length, 1);
  const first = saveAllocation(batch, batch.items[0]!.id, {
    revision: 0,
    requests: [{ school: 'IFES', requestedKg: 100 }],
  });
  assert.equal(batchNotifications(batch, first).length, 0);
  assert.equal(await repo.replace(first, 0), true);
  const completed = saveAllocation(first, first.items[1]!.id, {
    revision: 1,
    requests: [{ school: 'IFES', requestedKg: 10 }],
  });
  assert.equal(await repo.replace(completed, 1), true);
  assert.equal(await repo.replace(completed, 1), false);
  assert.deepEqual((await repo.notifications(0, 50)).map((n) => n.type).sort(), [
    'completed',
    'created',
  ]);
  assert.equal(batchNotifications(completed, { ...completed, revision: 3 }).length, 0);
  const sent: string[] = [];
  const gateway = {
    async subscribe() {},
    async send(n: { id: string }) {
      sent.push(n.id);
    },
  };
  await Promise.all([dispatchPush(repo, gateway), dispatchPush(repo, gateway)]);
  await dispatchPush(repo, gateway);
  assert.equal(sent.length, 2);
  assert.equal(new Set(sent).size, 2);
});

test('API de avisos compartilhada entre sessões, autenticação e inscrição push', async (t) => {
  const subscribed: unknown[] = [];
  const app = await buildApp({
    repository: new MemoryRepository(),
    ...credentials,
    logger: false,
    push: {
      async subscribe(token, enabled) {
        subscribed.push({ token, enabled });
      },
      async send() {},
    },
  });
  t.after(() => app.close());
  async function login() {
    const result = await app.inject({
      method: 'POST',
      url: '/v1/auth/login',
      payload: { cpf: credentials.mvpCpf, password: credentials.mvpPassword },
    });
    return { authorization: `Bearer ${result.json().accessToken}` };
  }
  const a = await login(),
    b = await login();
  assert.equal((await app.inject('/v1/notifications')).statusCode, 401);
  assert.equal((await app.inject('/v1/notifications/push-status')).statusCode, 401);
  const status = await app.inject({ url: '/v1/notifications/push-status', headers: b });
  assert.equal(status.statusCode, 200);
  assert.equal(status.json().configured, true);
  const created = await app.inject({
    method: 'POST',
    url: '/v1/batches',
    headers: a,
    payload: input,
  });
  assert.equal(created.statusCode, 201);
  const notice = await app.inject({ url: '/v1/notifications', headers: b });
  assert.equal(notice.json().data[0].batchId, created.json().id);
  assert.equal((await app.inject({ url: '/v1/notifications?page=0', headers: b })).statusCode, 400);
  const token = 'only-test-device-token-00000000';
  assert.equal(
    (
      await app.inject({
        method: 'POST',
        url: '/v1/notifications/push',
        payload: { token, enabled: true },
      })
    ).statusCode,
    401,
  );
  for (const enabled of [true, false]) {
    assert.equal(
      (
        await app.inject({
          method: 'POST',
          url: '/v1/notifications/push',
          headers: b,
          payload: { token, enabled },
        })
      ).statusCode,
      200,
    );
  }
  assert.equal(subscribed.length, 2);
});

test('push ausente informa indisponibilidade sem fingir inscrição', async (t) => {
  const app = await buildApp({ repository: new MemoryRepository(), ...credentials, logger: false });
  t.after(() => app.close());
  const login = await app.inject({
    method: 'POST',
    url: '/v1/auth/login',
    payload: { cpf: credentials.mvpCpf, password: credentials.mvpPassword },
  });
  const result = await app.inject({
    method: 'POST',
    url: '/v1/notifications/push',
    headers: { authorization: `Bearer ${login.json().accessToken}` },
    payload: { token: 'only-test-device-token-00000000', enabled: true },
  });
  const status = await app.inject({
    url: '/v1/notifications/push-status',
    headers: { authorization: `Bearer ${login.json().accessToken}` },
  });
  assert.equal(status.statusCode, 200);
  assert.equal(status.json().configured, false);
  assert.equal(result.statusCode, 503);
  assert.equal(result.json().error.code, 'PUSH_NOT_CONFIGURED');
});
