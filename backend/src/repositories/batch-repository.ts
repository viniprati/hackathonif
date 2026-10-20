import { MongoServerError, type Collection, type Db, type Filter } from 'mongodb';
import type { Batch } from '../domain/batch.js';

export interface BatchFilter {
  from?: string;
  toExclusive?: string;
  status?: 'pending' | 'completed';
}
export interface BatchRepository {
  insert(batch: Batch): Promise<void>;
  insertIfAbsent(batch: Batch): Promise<boolean>;
  get(id: string): Promise<Batch | null>;
  list(filter: BatchFilter, offset: number, limit: number): Promise<Batch[]>;
  count(filter: BatchFilter): Promise<number>;
  replace(batch: Batch, expectedRevision: number): Promise<boolean>;
}
interface BatchDocument extends Batch {
  _id: string;
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
    await this.collection.insertOne({ _id: batch.id, ...batch });
  }
  async insertIfAbsent(batch: Batch) {
    try {
      const result = await this.collection.updateOne(
        { _id: batch.id },
        { $setOnInsert: { _id: batch.id, ...batch } },
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
    const { _id, ...batch } = doc;
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
    return docs.map(({ _id, ...batch }) => batch);
  }
  async count(filter: BatchFilter) {
    return this.collection.countDocuments(this.filter(filter));
  }
  async replace(batch: Batch, expectedRevision: number) {
    const result = await this.collection.replaceOne(
      { _id: batch.id, revision: expectedRevision },
      batch,
    );
    return result.matchedCount === 1;
  }
}
