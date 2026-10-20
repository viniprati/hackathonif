import { cert, initializeApp, type ServiceAccount } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import type { BatchNotification } from './domain/notifications.js';
import type { BatchRepository } from './repositories/batch-repository.js';

export interface PushGateway {
  subscribe(token: string, enabled: boolean): Promise<void>;
  send(notice: BatchNotification): Promise<void>;
}
const topic = 'nativa-montantes';

interface TokenTopicClient {
  subscribeToTopicLegacy(
    tokens: string[],
    topic: string,
  ): Promise<{ failureCount: number; errors: { error: { code: string } }[] }>;
  unsubscribeFromTopicLegacy(
    tokens: string[],
    topic: string,
  ): Promise<{ failureCount: number; errors: { error: { code: string } }[] }>;
}
const safeProviderCodes = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
  'messaging/authentication-error',
  'messaging/mismatched-credential',
  'messaging/server-unavailable',
  'messaging/internal-error',
  'messaging/unknown-error',
  'messaging/topics-subscription-rate-exceeded',
  'messaging/too-many-topics',
  'app/invalid-credential',
  'app/network-error',
]);
export function safePushErrorCode(error: unknown): string {
  if (
    error &&
    typeof error === 'object' &&
    'code' in error &&
    typeof error.code === 'string' &&
    safeProviderCodes.has(error.code)
  )
    return error.code;
  return 'unknown';
}

/** Usa a gestão de tópicos compatível com os tokens getToken() do APK 1.4.0.
 * A API v1 do Admin 14 retornou authentication-error neste projeto; a API
 * compatível foi validada com a mesma credencial. Migrar antes de 29/09/2027.
 */
export async function subscribeRegistrationToken(
  client: TokenTopicClient,
  token: string,
  enabled: boolean,
): Promise<void> {
  const result = enabled
    ? await client.subscribeToTopicLegacy([token], topic)
    : await client.unsubscribeFromTopicLegacy([token], topic);
  if (result.failureCount) {
    const error = new Error('PushSubscriptionFailed') as Error & { code: string };
    error.code = safePushErrorCode(result.errors[0]?.error);
    throw error;
  }
}
export function firebasePush(raw: string | undefined): PushGateway | undefined {
  if (!raw) return undefined;
  const credentials = JSON.parse(raw) as ServiceAccount;
  const app = initializeApp({ credential: cert(credentials) }, 'nativa-push');
  const messaging = getMessaging(app);
  return {
    async subscribe(token, enabled) {
      await subscribeRegistrationToken(messaging, token, enabled);
    },
    async send(notice) {
      // Não coloca nomes ou dados financeiros na tela bloqueada.
      await messaging.send({
        topic,
        notification: {
          title: notice.type === 'created' ? 'Novo montante cadastrado' : 'Montante concluído',
          body: 'Abra o Nativa para consultar os detalhes.',
        },
        data: { noticeId: notice.id, batchId: notice.batchId },
        android: { priority: 'high', ttl: 86400000, notification: { tag: notice.id } },
      });
    },
  };
}

/// A fila reside no mesmo documento da alteração; sobrevive a reinícios.
export async function dispatchPush(repo: BatchRepository, gateway: PushGateway) {
  for (const notice of await repo.pendingNotifications()) {
    if (!(await repo.claimNotification(notice.id))) continue;
    await gateway.send(notice);
    await repo.markNotificationSent(notice.id);
  }
}
