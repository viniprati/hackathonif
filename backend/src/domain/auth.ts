import { randomBytes, scrypt, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
const derive = promisify(scrypt);

export async function hashPassword(password: string) {
  const salt = randomBytes(16).toString('hex');
  const key = (await derive(password, salt, 64)) as Buffer;
  return `scrypt$${salt}$${key.toString('hex')}`;
}
export async function verifyPassword(password: string, encoded: string) {
  const [algorithm, salt, expected] = encoded.split('$');
  if (algorithm !== 'scrypt' || !salt || !expected || !/^[a-f0-9]{128}$/.test(expected))
    return false;
  const key = (await derive(password, salt, 64)) as Buffer;
  return timingSafeEqual(key, Buffer.from(expected, 'hex'));
}
