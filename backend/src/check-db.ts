import { MongoClient, MongoServerError } from 'mongodb';
import { loadConfig } from './config.js';

const config = loadConfig();
const client = new MongoClient(config.mongoUri, {
  serverSelectionTimeoutMS: 8000,
  connectTimeoutMS: 8000,
  maxPoolSize: 2,
});
try {
  await client.connect();
  await client.db(config.dbName).command({ ping: 1 });
  console.info('MongoDB: conexão e ping confirmados. Nenhum dado foi gravado.');
} catch (error) {
  console.error(
    'MongoDB: conexão não confirmada. Confira credencial, rede e lista de IPs permitidos no Atlas.',
  );
  console.error(`Tipo de falha: ${error instanceof Error ? error.name : 'UnknownError'}`);
  if (error instanceof MongoServerError) {
    console.error(`Código: ${String(error.code ?? 'indisponível')}`);
    if (/bad auth|authentication failed|authentication failure/i.test(error.message))
      console.error('Autenticação recusada: revise o usuário de banco e a senha em MONGO_URI.');
  }
  process.exitCode = 1;
} finally {
  await client.close();
}
