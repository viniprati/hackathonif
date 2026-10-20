import { firebasePush, dispatchPush } from './push.js';
import { MongoClient } from 'mongodb';
import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { MongoBatchRepository } from './repositories/batch-repository.js';

async function main() {
  const config = loadConfig();
  const client = new MongoClient(config.mongoUri, {
    serverSelectionTimeoutMS: 8000,
    connectTimeoutMS: 8000,
    socketTimeoutMS: 10000,
    maxPoolSize: 10,
  });
  let app: Awaited<ReturnType<typeof buildApp>> | undefined;
  try {
    await client.connect();
    const db = client.db(config.dbName);
    await db.command({ ping: 1 });
    const repository = new MongoBatchRepository(db);
    await repository.initialize();
    const push = firebasePush(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    app = await buildApp({
      ...(push ? { push } : {}),
      repository,
      jwtSecret: config.jwtSecret,
      mvpCpf: config.mvpCpf,
      mvpPassword: config.mvpPassword,
      origins: config.origins,
      ping: async () => {
        await db.command({ ping: 1 });
      },
    });
    let dispatching = false;
    const pushTimer = push
      ? setInterval(() => {
          if (dispatching) return;
          dispatching = true;
          void dispatchPush(repository, push)
            .catch((error: unknown) => {
              app?.log.error(
                {
                  event: 'push_dispatch_failed',
                  errorType: error instanceof Error ? error.name : 'UnknownError',
                },
                'Não foi possível enviar os avisos push; a fila será tentada novamente',
              );
            })
            .finally(() => {
              dispatching = false;
            });
        }, 15000)
      : undefined;
    pushTimer?.unref();
    app.addHook('onClose', async () => {
      if (pushTimer) clearInterval(pushTimer);
      await client.close();
    });
    const shutdown = async () => {
      try {
        await app?.close();
      } catch {
        process.exitCode = 1;
      }
    };
    process.once('SIGTERM', shutdown);
    process.once('SIGINT', shutdown);
    await app.listen({ host: config.host, port: config.port });
    app.log.info({ event: 'service_ready' }, 'API Nativa pronta');
  } catch (error) {
    await app?.close();
    await client.close();
    console.error(
      `Não foi possível iniciar a API (${error instanceof Error ? error.name : 'UnknownError'}). Confira backend/.env, MongoDB Atlas e a porta configurada.`,
    );
    process.exitCode = 1;
  }
}
await main();
