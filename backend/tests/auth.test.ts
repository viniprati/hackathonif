import assert from 'node:assert/strict';
import test from 'node:test';
import { hashPassword, verifyPassword } from '../src/domain/auth.js';
import { buildApp } from '../src/app.js';
import { credentials, MemoryRepository } from './support.js';

test('senha é comparada por hash com salt e erros não validam o acesso', async () => {
  const hash = await hashPassword(credentials.mvpPassword);
  assert.ok(!hash.includes(credentials.mvpPassword));
  assert.notEqual(hash, await hashPassword(credentials.mvpPassword));
  assert.equal(await verifyPassword(credentials.mvpPassword, hash), true);
  assert.equal(await verifyPassword('wrong', hash), false);
  assert.equal(await verifyPassword('wrong', 'not-a-hash'), false);
});
test('login retorna JWT, CPF errado não autentica e token inválido é recusado', async (t) => {
  const app = await buildApp({ repository: new MemoryRepository(), ...credentials, logger: false });
  t.after(() => app.close());
  const wrong = await app.inject({
    method: 'POST',
    url: '/v1/auth/login',
    payload: { cpf: '00000000000', password: credentials.mvpPassword },
  });
  assert.equal(wrong.statusCode, 401);
  assert.ok(!wrong.body.includes(credentials.mvpPassword));
  const wrongPassword = await app.inject({
    method: 'POST',
    url: '/v1/auth/login',
    payload: { cpf: credentials.mvpCpf, password: 'incorrect' },
  });
  assert.equal(wrongPassword.statusCode, 401);
  const success = await app.inject({
    method: 'POST',
    url: '/v1/auth/login',
    payload: { cpf: credentials.mvpCpf, password: credentials.mvpPassword },
  });
  assert.equal(success.statusCode, 200);
  assert.equal(success.json().expiresIn, 3600);
  assert.ok(!success.body.includes(credentials.mvpPassword));
  const me = await app.inject({
    url: '/v1/auth/me',
    headers: { authorization: `Bearer ${success.json().accessToken}` },
  });
  assert.equal(me.statusCode, 200);
  assert.equal(me.json().id, 'mvp');
  const invalid = await app.inject({
    url: '/v1/auth/me',
    headers: { authorization: 'Bearer invalid-token' },
  });
  assert.equal(invalid.statusCode, 401);
  const wrongSubject = app.jwt.sign({ sub: 'another-user' });
  assert.equal(
    (await app.inject({ url: '/v1/batches', headers: { authorization: `Bearer ${wrongSubject}` } }))
      .statusCode,
    401,
  );
});
test('login limita tentativas repetidas', async (t) => {
  const app = await buildApp({ repository: new MemoryRepository(), ...credentials, logger: false });
  t.after(() => app.close());
  for (let attempt = 0; attempt < 5; attempt++) {
    const response = await app.inject({
      method: 'POST',
      url: '/v1/auth/login',
      payload: { cpf: credentials.mvpCpf, password: 'incorrect' },
    });
    assert.equal(response.statusCode, 401);
  }
  assert.equal(
    (
      await app.inject({
        method: 'POST',
        url: '/v1/auth/login',
        payload: { cpf: credentials.mvpCpf, password: 'incorrect' },
      })
    ).statusCode,
    429,
  );
});
