# API Nativa

Backend inicial em TypeScript para o MVP, separado do aplicativo Flutter. Usa Fastify e o driver oficial do MongoDB. Os montantes são persistidos em uma coleção `batches`; os testes comuns usam um repositório em memória e os testes de integração usam um MongoDB local temporário.

## O que está implementado

- Login com a conta única de demonstração configurada localmente, senha comparada com hash scrypt e JWT válido por uma hora.
- Catálogo fechado dos mesmos dez alimentos das notas e três escolas provisórias já usadas pelo Flutter.
- Consulta dos itens das duas notas de referência transcritas, sem dados pessoais dos documentos.
- Cadastro e consulta paginada de montantes, com data, alimentos, preços e escolas participantes.
- Distribuição por alimento apenas para escolas participantes. A soma dos pedidos não pode ultrapassar o recebido.
- Confirmação obrigatória do saldo e registro da perda em kg. O restante é sobra aproveitável.
- Relatórios semanais e mensais agrupados por alimento, com valores, perdas, sobras e distribuição por escola.
- Controle de revisão para impedir sobrescrita quando duas pessoas editam o mesmo montante.
- Logs JSON com identificação da requisição, rotas de saúde e limite de requisições e tentativas de login.

A API inicia sem montantes fictícios. Os catálogos e as notas são referências fixas copiadas do projeto, não consultas automáticas às escolas, associações ou serviços de notas fiscais.

**O Flutter ainda usa o repositório local em memória.** A integração HTTP, a troca do login de demonstração do Flutter pelo JWT e a persistência das preferências da interface são etapas seguintes. O PDF continua sendo gerado pelo Flutter; esta API retorna relatórios em JSON, com os dados necessários para gráficos e documentos.

## Pré-requisitos e configuração

- Node.js 22.13 ou superior e npm.
- MongoDB Atlas com usuário de banco autorizado a ler e escrever no banco escolhido, e o IP da máquina liberado no Network Access. O usuário de banco é diferente do login do painel Atlas.

A partir da raiz do repositório:

```sh
cd backend
npm ci
cp .env.example .env
```

Edite `backend/.env` localmente. Arquivos `.env`, `.ENV` e variantes são ignorados pelo Git. Não copie credenciais para arquivos versionados.

| Variável        | Função                                                                                                                                         |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `MONGO_URI`     | String de conexão do driver. Pode vir do `.ENV` já existente na raiz ou de `backend/.env`. Não é enviada aos clientes nem registrada nos logs. |
| `MONGO_DB_NAME` | Nome do banco de operação. Padrão: `nativa`. É explícito e prevalece sobre o nome presente na URI.                                             |
| `JWT_SECRET`    | Segredo aleatório de pelo menos 32 caracteres para assinar JWT. Deve permanecer somente no servidor.                                           |
| `MVP_CPF`       | Identificador de 11 dígitos da conta de teste. Não há validação dos dígitos verificadores nesta etapa.                                         |
| `MVP_PASSWORD`  | Senha local da conta de teste definida para o MVP.                                                                                             |
| `HOST`          | Endereço de escuta; padrão `127.0.0.1`, acessível apenas nesta máquina.                                                                        |
| `PORT`          | Porta HTTP; padrão `3000`.                                                                                                                     |
| `CORS_ORIGINS`  | Origens Web exatas separadas por vírgula. Vazio mantém acesso CORS desabilitado. Não substitui autenticação.                                   |

Variáveis do processo prevalecem sobre os arquivos. Depois, a ordem é `backend/.env`, `.ENV` da raiz e `.env` da raiz. Se a conexão estiver no `.ENV` da raiz, deixe `MONGO_URI` comentada no arquivo de exemplo do backend.

Para gerar um segredo local, execute e copie o resultado para `JWT_SECRET` no seu `.env`:

```sh
node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"
```

A configuração rejeita os valores de exemplo. A conta solicitada para este MVP já foi configurada no ambiente local de desenvolvimento; as credenciais não são distribuídas no repositório. Após clonar, cada ambiente precisa configurar essas variáveis. O modo de conta única é de demonstração e o servidor recusa `NODE_ENV=production` até que a autenticação de produção seja implementada.

## Executar

Dentro de `backend/`:

```sh
# Testa a conexão ao banco, sem gravar dados.
npm run db:check

# Desenvolvimento, com recarga ao editar arquivos.
npm run dev

# Compilação e execução do JavaScript gerado.
npm run build
npm start
```

A inicialização conecta ao MongoDB, verifica `ping` e cria o índice da coleção de montantes por data e identificador. Não cadastra montantes nem contas no Atlas. O encerramento por SIGINT/SIGTERM fecha a conexão.

Se `db:check` indicar autenticação recusada, revise o usuário de banco e a senha da URI no arquivo local. Caracteres reservados da senha precisam estar codificados na URI. A criação da conta de teste do aplicativo não altera as credenciais do MongoDB.

## Endpoints

Base local: `http://127.0.0.1:3000`. Todas as rotas `/v1`, exceto o login, exigem `Authorization: Bearer SEU_TOKEN`. Tokens e senhas nunca devem ser enviados pela URL.

| Método e rota                                             | Função                                                                                                     |
| --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `GET /health/live`                                        | Confirma que o processo HTTP responde.                                                                     |
| `GET /health/ready`                                       | Confirma disponibilidade do MongoDB; retorna 503 se o banco falhar.                                        |
| `POST /v1/auth/login`                                     | Recebe `cpf` e `password`; retorna `accessToken`, `tokenType`, `expiresIn` e perfil do usuário de teste.   |
| `GET /v1/auth/me`                                         | Perfil da sessão autenticada.                                                                              |
| `GET /v1/catalog/foods`                                   | Alimentos e preços de referência.                                                                          |
| `GET /v1/catalog/schools`                                 | Lista definida de escolas.                                                                                 |
| `GET /v1/catalog/invoices`                                | Notas e itens de referência.                                                                               |
| `POST /v1/batches`                                        | Cadastra montante com revisão inicial zero.                                                                |
| `GET /v1/batches`                                         | Lista montantes. Filtros `from`, `to` inclusivo, `status=pending\|completed`, `page` e `limit` de 1 a 100. |
| `GET /v1/batches/:batchId`                                | Montante, revisão e alimentos com identificadores.                                                         |
| `PUT /v1/batches/:batchId/items/:itemId/allocation`       | Salva a distribuição e classificação do saldo de um alimento.                                              |
| `GET /v1/reports/foods?period=month&reference=2026-10-19` | Relatório mensal; use `period=week` para a semana de segunda a domingo que contém a referência.            |

Exemplo de corpo para cadastro de montante:

```json
{
  "name": "Montante de outubro",
  "date": "2026-10-20",
  "participatingSchools": ["IFES", "Darllin"],
  "items": [
    {
      "product": "Aipim",
      "receivedKg": 100,
      "unitPriceCents": 572,
      "invoiceNumber": "190720001"
    }
  ]
}
```

- Datas usam `AAAA-MM-DD`, sem horário. O filtro de período usa a data do montante.
- Quantidades usam kg em passos de 0,1; internamente são armazenadas como inteiros de décimos de kg. O limite inicial é 1.000.000 kg por alimento.
- Valores monetários são inteiros em centavos. O limite inicial do preço é 1.000.000 centavos/kg. Se o preço não for conhecido, omita `unitPriceCents` ou use `null`; não use zero para representar um preço desconhecido.
- Vincular uma nota exige que alimento e preço correspondam ao item transcrito. Omitir a nota permite preço informado manualmente. O preço de referência do catálogo não é aplicado automaticamente a um recebimento.
- Identificadores são UUIDs gerados pelo servidor. `status`, cálculos e datas de criação não podem ser definidos no cadastro pelo cliente.

Exemplo de distribuição, quando o recebido é 100 kg e há saldo de 40 kg:

```json
{
  "revision": 0,
  "requests": [{ "school": "IFES", "requestedKg": 60 }],
  "remainderConfirmed": true,
  "lossKg": 10
}
```

O resultado é 60 kg distribuídos, 10 kg de perda e 30 kg de sobra aproveitável. Uma escola participante omitida fica com pedido zero. Se não houver saldo, `remainderConfirmed` e `lossKg` são opcionais; a perda só pode ser zero nesse caso.

Sempre envie a revisão obtida no último `GET`. O servidor incrementa a revisão do montante inteiro em cada gravação. Retorno **409** significa que outra alteração ocorreu: recarregue os dados e revise o formulário antes de tentar salvar novamente. A gravação compara a revisão atomicamente em um único documento MongoDB, sem depender de transações entre coleções.

Outros retornos: **400** para estrutura/tipos inválidos; **401** para sessão ausente, inválida ou expirada; **404** para identificador não encontrado; **422** para regra de negócio; **429** para limite de requisições. Respostas de erro incluem `requestId`, também enviado no cabeçalho `x-request-id` para correlação com os logs. Falhas inesperadas não devolvem detalhes da conexão.

Os relatórios preservam centavos ao dividir valores entre situações e escolas. Recebimentos sem preço aparecem em `unpricedCount` e deixam os valores parciais. Montantes pendentes não são tratados como perdas. Há um limite de 10.000 montantes por relatório; os totais das notas de referência não são somados ao estoque. A finalização comprova o salvamento do rateio, não uma entrega física.

## Testes e verificações

```sh
npm run typecheck
npm test
npm run test:integration
npm run build
npm audit --omit=dev
```

Os testes comuns usam injeção HTTP do Fastify e repositório de teste em memória; não acessam o Atlas. Os testes de integração iniciam um processo MongoDB local temporário com `mongodb-memory-server-core`, verificam persistência, índices, filtros e concorrência real e encerram a instância ao terminar. Na primeira execução, essa ferramenta baixa um binário MongoDB e precisa de acesso à Internet e bibliotecas nativas compatíveis.

Nenhum teste usa a credencial Atlas do arquivo local para criar, remover ou popular bancos. Para conferir somente a conexão configurada, use `npm run db:check`.

## Estrutura

```text
src/app.ts                    Aplicação HTTP e autenticação JWT
src/server.ts                 Inicialização, conexão e encerramento
src/config.ts                 Configuração por ambiente
src/check-db.ts               Verificação de conexão sem escrita
src/domain/                   Regras de montantes, relatórios e conta MVP
src/repositories/             Persistência MongoDB e controle de revisão
src/routes/                   Contratos JSON e rotas de negócio
tests/                        Testes de regras e HTTP
tests/integration/            MongoDB local temporário
```

## Próximos passos

- Integrar o repositório e o login do Flutter à API, incluindo armazenamento seguro do token e tratamento de sessão expirada/conflitos.
- Substituir a conta local de demonstração por usuários persistidos, perfis de acesso e recuperação de senha.
- Definir hospedagem, HTTPS, configuração de proxy e estratégia de backup.
- Substituir as três escolas provisórias pelo catálogo oficial e validar o fluxo com a associação.

Referências: [Fastify](https://fastify.dev/docs/latest/), [driver MongoDB](https://www.mongodb.com/docs/drivers/node/current/), [JWT para Fastify](https://github.com/fastify/fastify-jwt), [MongoDB temporário para testes](https://github.com/typegoose/mongodb-memory-server).
