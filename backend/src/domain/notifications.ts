import type { Batch } from './batch.js';

export interface BatchNotification {
  id: string;
  batchId: string;
  batchName: string;
  type: 'created' | 'completed';
  createdAt: string;
}
export function batchNotifications(previous: Batch | null, next: Batch): BatchNotification[] {
  const events: BatchNotification[] = [];
  const event = (type: BatchNotification['type']): BatchNotification => ({
    id: `${next.id}:${type}:${next.revision}`,
    batchId: next.id,
    batchName: next.name,
    type,
    createdAt: next.updatedAt,
  });
  if (!previous) events.push(event('created'));
  if (
    next.items.every((item) => item.status === 'completed') &&
    (!previous || previous.items.some((item) => item.status === 'pending'))
  ) {
    events.push(event('completed'));
  }
  return events;
}
