import { MongoServerError, type Collection, type Db, type Filter } from 'mongodb';
import { batchNotifications, type BatchNotification } from '../domain/notifications.js';
import type { Batch } from '../domain/batch.js';

export interface BatchFilter {
  from?: string;
  toExclusive?: string;
  status?: 'pending' | 'completed';
}
export interface BatchRepository {
  pendingNotifications(): Promise<BatchNotification[]>;
  claimNotification(id: string): Promise<boolean>;
  markNotificationSent(id: string): Promise<void>;
  notifications(offset: number, limit: number): Promise<BatchNotification[]>;
  insert(batch: Batch): Promise<void>;
  insertIfAbsent(batch: Batch): Promise<boolean>;
  get(id: string): Promise<Batch | null>;
  list(filter: BatchFilter, offset: number, limit: number): Promise<Batch[]>;
  count(filter: BatchFilter): Promise<number>;
  replace(batch: Batch, expectedRevision: number): Promise<boolean>;
}
interface BatchDocument extends Batch {
  _id: string;
  activity?: (BatchNotification & { pushSentAt?: Date; pushLeaseUntil?: Date })[];
}
export class MongoBatchRepository implements BatchRepository {
  private readonly collection: Collection<BatchDocument>;
  constructor(db: Db) {
    this.collection = db.collection<BatchDocument>('batches');
  }
  async initialize() {
    await this.collection.createIndex({ date: -1, _id: 1 });
  }
  async insert(batch: Batch) {
    await this.collection.insertOne({
      _id: batch.id,
      ...batch,
      activity: batchNotifications(null, batch),
    });
  }
  async insertIfAbsent(batch: Batch) {
    try {
      const result = await this.collection.updateOne(
        { _id: batch.id },
        { $setOnInsert: { _id: batch.id, ...batch, activity: batchNotifications(null, batch) } },
        { upsert: true },
      );
      return result.upsertedCount === 1;
    } catch (error) {
      if (error instanceof MongoServerError && error.code === 11000) return false;
      throw error;
    }
  }
  async get(id: string) {
    const doc = await this.collection.findOne({ _id: id });
    if (!doc) return null;
    const { _id, activity, ...batch } = doc;
    return batch;
  }
  private filter(input: BatchFilter): Filter<BatchDocument> {
    const filter: Filter<BatchDocument> = {};
    if (input.from || input.toExclusive) {
      filter.date = {
        ...(input.from ? { $gte: input.from } : {}),
        ...(input.toExclusive ? { $lt: input.toExclusive } : {}),
      };
    }
    if (input.status === 'pending') filter['items.status'] = 'pending';
    if (input.status === 'completed') filter['items.status'] = { $ne: 'pending' };
    return filter;
  }
  async list(filter: BatchFilter, offset: number, limit: number) {
    const docs = await this.collection
      .find(this.filter(filter))
      .sort({ date: -1, _id: 1 })
      .skip(offset)
      .limit(limit)
      .toArray();
    return docs.map(({ _id, activity, ...batch }) => batch);
  }
  async count(filter: BatchFilter) {
    return this.collection.countDocuments(this.filter(filter));
  }
  async pendingNotifications(): Promise<BatchNotification[]> {
    return this.collection
      .aggregate<BatchNotification>([
        { $unwind: '$activity' },
        {
          $match: {
            'activity.pushSentAt': { $exists: false },
            'activity.createdAt': { $gte: new Date(Date.now() - 86400000).toISOString() },
            $or: [
              { 'activity.pushLeaseUntil': { $exists: false } },
              { 'activity.pushLeaseUntil': { $lt: new Date() } },
            ],
          },
        },
        { $replaceRoot: { newRoot: '$activity' } },
        { $sort: { createdAt: 1, type: -1, id: 1 } },
        { $limit: 20 },
      ])
      .toArray();
  }
  async claimNotification(id: string): Promise<boolean> {
    const result = await this.collection.updateOne(
      {
        activity: {
          $elemMatch: {
            id,
            pushSentAt: { $exists: false },
            $or: [{ pushLeaseUntil: { $exists: false } }, { pushLeaseUntil: { $lt: new Date() } }],
          },
        },
      },
      { $set: { 'activity.$.pushLeaseUntil': new Date(Date.now() + 120000) } },
    );
    return result.modifiedCount === 1;
  }
  async markNotificationSent(id: string) {
    await this.collection.updateOne(
      { 'activity.id': id },
      { $set: { 'activity.$.pushSentAt': new Date() } },
    );
  }
  async notifications(offset: number, limit: number): Promise<BatchNotification[]> {
    return this.collection
      .aggregate<BatchNotification>([
        { $unwind: '$activity' },
        { $replaceRoot: { newRoot: '$activity' } },
        { $project: { id: 1, batchId: 1, batchName: 1, type: 1, createdAt: 1 } },
        { $sort: { createdAt: -1, id: -1 } },
        { $skip: offset },
        { $limit: limit },
      ])
      .toArray();
  }
  async replace(batch: Batch, expectedRevision: number) {
    const previous = await this.get(batch.id);
    if (!previous || previous.revision !== expectedRevision) return false;
    const events = batchNotifications(previous, batch);
    // Estado e avisos são gravados atomicamente no mesmo documento.
    const result = await this.collection.updateOne(
      { _id: batch.id, revision: expectedRevision },
      {
        $set: batch,
        ...(events.length ? { $push: { activity: { $each: events, $slice: -200 } } } : {}),
      },
    );
    return result.matchedCount === 1;
  }
}
