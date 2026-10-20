import assert from 'node:assert/strict';
import test from 'node:test';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { MongoClient } from 'mongodb';
import { MongoMemoryServer } from 'mongodb-memory-server-core';
import { buildApp } from '../../src/app.js';
import { MongoBatchRepository } from '../../src/repositories/batch-repository.js';
import { credentials } from '../support.js';

test(
  'Flutter cliente real compartilha montantes via HTTP e MongoDB isolado',
  {
    timeout: 240000,
    skip: !process.env.FLUTTER_BIN && 'Configure FLUTTER_BIN para executar a integração Flutter.',
  },
  async (t) => {
    const mongod = await MongoMemoryServer.create({ instance: { launchTimeout: 30000 } });
    t.after(() => mongod.stop());
    const client = await new MongoClient(mongod.getUri()).connect();
    t.after(() => client.close());
    const db = client.db('nativa_flutter_sync_test');
    const repository = new MongoBatchRepository(db);
    await repository.initialize();
    const app = await buildApp({ repository, ...credentials, logger: false });
    t.after(() => app.close());
    const base = await app.listen({ host: '127.0.0.1', port: 0 });
    const output = await new Promise<{ code: number | null; text: string }>((resolve, reject) => {
      const child = spawn(
        process.env.FLUTTER_BIN!,
        ['test', 'test/integration/manual_sync_api_test.dart', '--reporter', 'expanded'],
        {
          cwd: fileURLToPath(new URL('../../../', import.meta.url)),
          timeout: 200000,
          env: {
            ...process.env,
            NATIVA_SYNC_TEST_URL: base,
            NATIVA_SYNC_TEST_CPF: credentials.mvpCpf,
            NATIVA_SYNC_TEST_PASSWORD: credentials.mvpPassword,
          },
          stdio: ['ignore', 'pipe', 'pipe'],
        },
      );
      let text = '';
      child.stdout.on('data', (chunk) => {
        text += String(chunk);
      });
      child.stderr.on('data', (chunk) => {
        text += String(chunk);
      });
      child.on('error', reject);
      child.on('exit', (code) => resolve({ code, text }));
    });
    assert.equal(output.code, 0, output.text);
    t.diagnostic(output.text.split('\n').slice(-5).join('\n'));
    assert.equal(await repository.count({}), 2);
    const batches = await repository.list({}, 0, 20);
    assert.equal(batches.find((batch) => batch.name === 'Compartilhado isolado')!.revision, 2);
  },
);
