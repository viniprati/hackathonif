import type { FastifyInstance } from 'fastify';
import { syncBatch, batchContent, type SyncBatchInput } from '../domain/sync.js';
import {
  batchDto,
  createBatch,
  DomainError,
  saveAllocation,
  validDate,
  type CreateBatch,
  type SaveAllocation,
} from '../domain/batch.js';
import { foods, invoices, schools } from '../domain/catalog.js';
import { reportWindow, stockReport } from '../domain/report.js';
import type { BatchFilter, BatchRepository } from '../repositories/batch-repository.js';

const date = { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' };
const quantity = { type: 'number', minimum: 0, maximum: 1_000_000, multipleOf: 0.1 };
const id = {
  type: 'string',
  pattern: '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
};
const batchParams = {
  type: 'object',
  additionalProperties: false,
  required: ['batchId'],
  properties: { batchId: id },
};
const createBody = {
  type: 'object',
  additionalProperties: false,
  required: ['name', 'date', 'participatingSchools', 'items'],
  properties: {
    name: { type: 'string', minLength: 1, maxLength: 120 },
    date,
    participatingSchools: {
      type: 'array',
      minItems: 1,
      maxItems: schools.length,
      uniqueItems: true,
      items: { type: 'string', enum: [...schools] },
    },
    items: {
      type: 'array',
      minItems: 1,
      maxItems: foods.length,
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['product', 'receivedKg'],
        properties: {
          product: { type: 'string', enum: foods.map((food) => food.name) },
          receivedKg: { ...quantity, minimum: 0.1 },
          unitPriceCents: { type: ['integer', 'null'], minimum: 0, maximum: 1_000_000 },
          invoiceNumber: {
            type: ['string', 'null'],
            enum: [...invoices.map((invoice) => invoice.number), null],
          },
        },
      },
    },
  },
};
const allocationBody = {
  type: 'object',
  additionalProperties: false,
  required: ['revision', 'requests'],
  properties: {
    revision: { type: 'integer', minimum: 0, maximum: Number.MAX_SAFE_INTEGER },
    requests: {
      type: 'array',
      minItems: 0,
      maxItems: schools.length,
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['school', 'requestedKg'],
        properties: {
          school: { type: 'string', enum: [...schools] },
          requestedKg: quantity,
        },
      },
    },
    remainderConfirmed: { type: 'boolean' },
    lossKg: quantity,
  },
};

const syncBody = {
  ...createBody,
  required: [...createBody.required, 'revision'],
  properties: {
    ...createBody.properties,
    revision: { type: ['integer', 'null'], minimum: 0, maximum: Number.MAX_SAFE_INTEGER },
    items: {
      ...createBody.properties.items,
      items: {
        ...createBody.properties.items.items,
        required: [...createBody.properties.items.items.required, 'status', 'requests', 'lossKg'],
        properties: {
          ...createBody.properties.items.items.properties,
          status: { type: 'string', enum: ['pending', 'completed'] },
          requests: allocationBody.properties.requests,
          lossKg: { ...quantity, type: ['number', 'null'] },
        },
      },
    },
  },
};

export async function batchRoutes(app: FastifyInstance, repo: BatchRepository) {
  app.get<{ Querystring: { page?: string } }>(
    '/notifications',
    {
      schema: {
        querystring: {
          type: 'object',
          additionalProperties: false,
          properties: { page: { type: 'string', pattern: '^[1-9][0-9]{0,3}$' } },
        },
      },
    },
    async (request) => {
      const page = Number(request.query.page ?? 1);
      return { data: await repo.notifications((page - 1) * 50, 50), page, limit: 50 };
    },
  );
  app.get('/catalog/foods', async () => ({ foods }));
  app.get('/catalog/schools', async () => ({ schools }));
  app.get('/catalog/invoices', async () => ({ invoices }));
  app.post<{ Body: CreateBatch }>(
    '/batches',
    { schema: { body: createBody } },
    async (request, reply) => {
      const batch = createBatch(request.body);
      await repo.insert(batch);
      request.log.info(
        { event: 'batch_created', batchId: batch.id, revision: batch.revision },
        'Montante cadastrado',
      );
      return reply.code(201).header('location', `/v1/batches/${batch.id}`).send(batchDto(batch));
    },
  );
  app.put<{ Params: { batchId: string }; Body: SyncBatchInput }>(
    '/batches/:batchId/sync',
    { schema: { params: batchParams, body: syncBody } },
    async (request, reply) => {
      const id = request.params.batchId;
      let previous = await repo.get(id);
      const next = syncBatch(id, request.body, previous);
      // Repetir uma gravação já aplicada não duplica montantes nem avança a revisão.
      if (previous && batchContent(previous) === batchContent(next)) return batchDto(previous);
      if (previous && request.body.revision !== previous.revision)
        throw new DomainError(
          'REVISION_CONFLICT',
          'Outro usuário alterou este montante. Revise as versões antes de sincronizar.',
          409,
        );
      if (!previous && request.body.revision !== null)
        throw new DomainError(
          'REVISION_CONFLICT',
          'O montante não está mais disponível no banco.',
          409,
        );
      if (previous) {
        if (!(await repo.replace(next, previous.revision)))
          throw new DomainError(
            'REVISION_CONFLICT',
            'O montante foi alterado durante a sincronização.',
            409,
          );
      } else if (!(await repo.insertIfAbsent(next))) {
        previous = await repo.get(id);
        if (previous && batchContent(previous) === batchContent(next)) return batchDto(previous);
        throw new DomainError(
          'REVISION_CONFLICT',
          'Este montante já existe com outros dados.',
          409,
        );
      }
      request.log.info(
        { event: 'batch_synced', batchId: id, revision: next.revision },
        'Montante sincronizado',
      );
      return reply.code(previous ? 200 : 201).send(batchDto(next));
    },
  );
  app.get<{
    Querystring: {
      from?: string;
      to?: string;
      status?: 'pending' | 'completed';
      page?: string;
      limit?: string;
    };
  }>(
    '/batches',
    {
      schema: {
        querystring: {
          type: 'object',
          additionalProperties: false,
          properties: {
            from: date,
            to: date,
            status: { type: 'string', enum: ['pending', 'completed'] },
            page: { type: 'string', pattern: '^[1-9][0-9]{0,3}$' },
            limit: { type: 'string', pattern: '^([1-9][0-9]?|100)$' },
          },
        },
      },
    },
    async (request) => {
      const { from, to, status } = request.query;
      if (from) validDate(from);
      if (to) validDate(to);
      if (from && to && from > to)
        throw new DomainError('INVALID_WINDOW', 'A data inicial deve ser anterior à final.');
      const next = to ? new Date(`${to}T00:00:00.000Z`) : null;
      if (next) next.setUTCDate(next.getUTCDate() + 1);
      const filter: BatchFilter = {
        ...(from ? { from } : {}),
        ...(next ? { toExclusive: next.toISOString().slice(0, 10) } : {}),
        ...(status ? { status } : {}),
      };
      const page = Number(request.query.page ?? 1);
      const limit = Number(request.query.limit ?? 20);
      const [batches, total] = await Promise.all([
        repo.list(filter, (page - 1) * limit, limit),
        repo.count(filter),
      ]);
      return { data: batches.map(batchDto), page, limit, total };
    },
  );
  app.get<{ Params: { batchId: string } }>(
    '/batches/:batchId',
    { schema: { params: batchParams } },
    async (request) => {
      const batch = await repo.get(request.params.batchId);
      if (!batch) throw new DomainError('BATCH_NOT_FOUND', 'Montante não encontrado.', 404);
      return batchDto(batch);
    },
  );
  app.put<{ Params: { batchId: string; itemId: string }; Body: SaveAllocation }>(
    '/batches/:batchId/items/:itemId/allocation',
    {
      schema: {
        params: {
          ...batchParams,
          required: ['batchId', 'itemId'],
          properties: { batchId: id, itemId: id },
        },
        body: allocationBody,
      },
    },
    async (request) => {
      const batch = await repo.get(request.params.batchId);
      if (!batch) throw new DomainError('BATCH_NOT_FOUND', 'Montante não encontrado.', 404);
      const next = saveAllocation(batch, request.params.itemId, request.body);
      if (!(await repo.replace(next, batch.revision)))
        throw new DomainError(
          'REVISION_CONFLICT',
          'Outro usuário atualizou o montante. Recarregue antes de salvar.',
          409,
        );
      request.log.info(
        {
          event: 'allocation_saved',
          batchId: next.id,
          itemId: request.params.itemId,
          revision: next.revision,
        },
        'Distribuição salva',
      );
      return batchDto(next);
    },
  );
  app.get<{ Querystring: { period: 'week' | 'month'; reference: string } }>(
    '/reports/foods',
    {
      schema: {
        querystring: {
          type: 'object',
          additionalProperties: false,
          required: ['period', 'reference'],
          properties: { period: { type: 'string', enum: ['week', 'month'] }, reference: date },
        },
      },
    },
    async (request) => {
      const { period, reference } = request.query;
      const window = reportWindow(period, reference);
      const filter = { from: window.start, toExclusive: window.endExclusive };
      const batches = await repo.list(filter, 0, 10001);
      if (batches.length > 10000)
        throw new DomainError('REPORT_LIMIT', 'Escolha um período com até 10.000 montantes.');
      return stockReport(batches, period, reference);
    },
  );
}
