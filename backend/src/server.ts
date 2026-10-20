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
    app = await buildApp({
      repository,
      jwtSecret: config.jwtSecret,
      mvpCpf: config.mvpCpf,
      mvpPassword: config.mvpPassword,
      origins: config.origins,
      ping: async () => {
        await db.command({ ping: 1 });
      },
    });
    app.addHook('onClose', async () => {
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
