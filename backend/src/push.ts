import { cert, initializeApp, type ServiceAccount } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import type { BatchNotification } from './domain/notifications.js';
import type { BatchRepository } from './repositories/batch-repository.js';

export interface PushGateway {
  subscribe(token: string, enabled: boolean): Promise<void>;
  send(notice: BatchNotification): Promise<void>;
}
const topic = 'nativa-montantes';
export function firebasePush(raw: string | undefined): PushGateway | undefined {
  if (!raw) return undefined;
  const credentials = JSON.parse(raw) as ServiceAccount;
  const app = initializeApp({ credential: cert(credentials) }, 'nativa-push');
  const messaging = getMessaging(app);
  return {
    async subscribe(token, enabled) {
      const result = enabled
        ? await messaging.subscribeToTopic([token], topic)
        : await messaging.unsubscribeFromTopic([token], topic);
      if (result.failureCount) throw new Error('PushSubscriptionFailed');
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
