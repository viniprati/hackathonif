import { fileURLToPath } from 'node:url';
import { config as dotenv } from 'dotenv';

export function loadConfig() {
  dotenv({
    path: [
      fileURLToPath(new URL('../.env', import.meta.url)),
      fileURLToPath(new URL('../../.ENV', import.meta.url)),
      fileURLToPath(new URL('../../.env', import.meta.url)),
    ],
    quiet: true,
  });
  const mongoUri = process.env.MONGO_URI;
  const jwtSecret = process.env.JWT_SECRET;
  const mvpCpf = process.env.MVP_CPF;
  const mvpPassword = process.env.MVP_PASSWORD;
  if (process.env.NODE_ENV === 'production')
    throw new Error(
      'A conta única do MVP é apenas para desenvolvimento; configure autenticação de produção antes de publicar.',
    );
  if (
    !mvpCpf ||
    !/^\d{11}$/.test(mvpCpf) ||
    !mvpPassword ||
    mvpPassword === 'SUBSTITUA_LOCALMENTE' ||
    mvpPassword.length > 128
  )
    throw new Error('Configure MVP_CPF (11 dígitos) e MVP_PASSWORD em backend/.env.');
  if (!mongoUri || !/^mongodb(\+srv)?:\/\//.test(mongoUri))
    throw new Error('Configure MONGO_URI no .ENV da raiz ou em backend/.env.');
  if (!jwtSecret || jwtSecret.startsWith('SUBSTITUA_') || jwtSecret.length < 32)
    throw new Error('Configure JWT_SECRET com ao menos 32 caracteres em backend/.env.');
  const port = Number(process.env.PORT ?? 3000);
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('PORT inválida.');
  const dbName = process.env.MONGO_DB_NAME ?? 'nativa';
  if (!/^[a-zA-Z0-9_-]{1,63}$/.test(dbName)) throw new Error('MONGO_DB_NAME inválido.');
  const host = process.env.HOST ?? '127.0.0.1';
  const origins = (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  return { mongoUri, jwtSecret, mvpCpf, mvpPassword, port, dbName, host, origins };
}
