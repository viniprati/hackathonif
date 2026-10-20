import { safePushErrorCode, type PushGateway } from './push.js';
import { randomUUID } from 'node:crypto';
import Fastify, { type FastifyError } from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import jwt from '@fastify/jwt';
import { hashPassword, verifyPassword } from './domain/auth.js';
import { DomainError } from './domain/batch.js';
import type { BatchRepository } from './repositories/batch-repository.js';
import { batchRoutes } from './routes/batches.js';

interface Options {
  repository: BatchRepository;
  push?: PushGateway;
  jwtSecret: string;
  mvpCpf: string;
  mvpPassword: string;
  origins?: string[];
  logger?: boolean;
  ping?: () => Promise<void>;
}
export async function buildApp(options: Options) {
  if (options.jwtSecret.length < 32) throw new Error('JWT_SECRET deve ter ao menos 32 caracteres.');
  const passwordHash = await hashPassword(options.mvpPassword);
  const app = Fastify({
    logger:
      options.logger === false
        ? false
        : {
            level: 'info',
            redact: [
              'req.headers.authorization',
              'req.headers.cookie',
              'res.headers["set-cookie"]',
            ],
            serializers: { req: (req) => ({ method: req.method, route: req.url?.split('?')[0] }) },
          },
    genReqId: () => randomUUID(),
    bodyLimit: 64 * 1024,
    requestTimeout: 15000,
    ajv: { customOptions: { removeAdditional: false, coerceTypes: false, multipleOfPrecision: 8 } },
  });
  app.addHook('onRequest', async (request, reply) => {
    reply.header('x-request-id', request.id);
  });
  await app.register(jwt, {
    secret: options.jwtSecret,
    sign: { expiresIn: '1h', iss: 'nativa-api', aud: 'nativa-app' },
    verify: { allowedIss: 'nativa-api', allowedAud: 'nativa-app', algorithms: ['HS256'] },
  });
  await app.register(helmet);
  await app.register(cors, {
    origin: options.origins?.length ? options.origins : false,
    methods: ['GET', 'HEAD', 'POST', 'PUT'],
  });
  await app.register(rateLimit, { max: 100, timeWindow: '1 minute' });
  app.setErrorHandler((error, request, reply) => {
    if (error instanceof DomainError) {
      return reply
        .code(error.status)
        .send({ error: { code: error.code, message: error.message }, requestId: request.id });
    }
    const failure = error instanceof Error ? (error as Partial<FastifyError>) : undefined;
    if (failure?.validation) {
      return reply.code(400).send({
        error: {
          code: 'INVALID_REQUEST',
          message: 'Confira os campos enviados e os tipos dos dados.',
        },
        requestId: request.id,
      });
    }
    if (failure?.statusCode && failure.statusCode >= 400 && failure.statusCode < 500) {
      return reply.code(failure.statusCode).send({
        error: { code: failure.code ?? 'REQUEST_ERROR', message: 'Requisição não permitida.' },
        requestId: request.id,
      });
    }
    request.log.error(
      {
        event: 'request_failed',
        errorType: error instanceof Error ? error.name : 'UnknownError',
        requestId: request.id,
      },
      'Falha na requisição',
    );
    return reply.code(500).send({
      error: { code: 'INTERNAL_ERROR', message: 'Não foi possível concluir a operação.' },
      requestId: request.id,
    });
  });
  app.setNotFoundHandler(async (request, reply) =>
    reply.code(404).send({
      error: { code: 'ROUTE_NOT_FOUND', message: 'Rota não encontrada.' },
      requestId: request.id,
    }),
  );
  app.get('/health/live', async () => ({ status: 'ok' }));
  app.get('/health/ready', async (request, reply) => {
    try {
      await options.ping?.();
      return { status: 'ok', database: 'available' };
    } catch {
      request.log.warn({ event: 'database_unavailable' }, 'Banco indisponível');
      return reply.code(503).send({ status: 'unavailable', database: 'unavailable' });
    }
  });
  app.post<{ Body: { cpf: string; password: string } }>(
    '/v1/auth/login',
    {
      config: { rateLimit: { max: 5, timeWindow: '1 minute' } },
      schema: {
        body: {
          type: 'object',
          additionalProperties: false,
          required: ['cpf', 'password'],
          properties: {
            cpf: { type: 'string', pattern: '^\\d{11}$' },
            password: { type: 'string', minLength: 1, maxLength: 128 },
          },
        },
      },
    },
    async (request, reply) => {
      const matches = await verifyPassword(request.body.password, passwordHash);
      if (!matches || request.body.cpf !== options.mvpCpf) {
        return reply.code(401).send({
          error: { code: 'INVALID_CREDENTIALS', message: 'CPF ou senha inválidos.' },
          requestId: request.id,
        });
      }
      request.log.info({ event: 'login_succeeded' }, 'Login de demonstração realizado');
      return {
        accessToken: await reply.jwtSign({ sub: 'mvp', jti: randomUUID() }),
        tokenType: 'Bearer',
        expiresIn: 3600,
        user: { id: 'mvp', name: 'Usuário MVP' },
      };
    },
  );
  await app.register(
    async (api) => {
      api.addHook('onRequest', async (request, reply) => {
        try {
          const claims = await request.jwtVerify<{ sub: string }>();
          if (claims.sub !== 'mvp') throw new Error('Invalid subject');
        } catch {
          return reply
            .code(401)
            .header('www-authenticate', 'Bearer')
            .send({
              error: { code: 'UNAUTHORIZED', message: 'Autenticação necessária.' },
              requestId: request.id,
            });
        }
      });
      api.get('/auth/me', async () => ({ id: 'mvp', name: 'Usuário MVP' }));
      api.get('/notifications/push-status', async () => ({
        configured: Boolean(options.push),
        registrationProtocol: 'fcm-token-compatible',
      }));
      api.post<{ Body: { token: string; enabled: boolean } }>(
        '/notifications/push',
        {
          config: { rateLimit: { max: 10, timeWindow: '1 minute' } },
          schema: {
            body: {
              type: 'object',
              additionalProperties: false,
              required: ['token', 'enabled'],
              properties: {
                token: { type: 'string', minLength: 20, maxLength: 4096 },
                enabled: { type: 'boolean' },
              },
            },
          },
        },
        async (request, reply) => {
          if (!options.push)
            return reply.code(503).send({
              error: {
                code: 'PUSH_NOT_CONFIGURED',
                message: 'O envio push ainda não foi configurado.',
              },
            });
          const started = Date.now();
          try {
            await options.push.subscribe(request.body.token, request.body.enabled);
            request.log.info(
              {
                event: 'push_subscription_updated',
                enabled: request.body.enabled,
                durationMs: Date.now() - started,
                requestId: request.id,
              },
              'Inscrição push atualizada',
            );
            return { enabled: request.body.enabled };
          } catch (error) {
            const providerCode = safePushErrorCode(error);
            request.log.warn(
              {
                event: 'push_subscription_failed',
                providerCode,
                enabled: request.body.enabled,
                durationMs: Date.now() - started,
                requestId: request.id,
              },
              'Falha na inscrição push',
            );
            const invalidToken =
              providerCode === 'messaging/invalid-registration-token' ||
              providerCode === 'messaging/registration-token-not-registered';
            return reply.code(invalidToken ? 400 : 503).send({
              error: {
                code: invalidToken ? 'PUSH_INVALID_TOKEN' : 'PUSH_REGISTRATION_FAILED',
                message: invalidToken
                  ? 'O registro deste aparelho expirou. Desative e ative as notificações para tentar novamente.'
                  : 'O serviço de notificações não confirmou o registro. Aguarde e tente novamente.',
              },
              requestId: request.id,
            });
          }
        },
      );
      await batchRoutes(api, options.repository);
    },
    { prefix: '/v1' },
  );
  return app;
}
