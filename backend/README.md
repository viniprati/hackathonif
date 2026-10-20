# API Nativa

Backend inicial em TypeScript para o MVP, separado do aplicativo Flutter. Usa Fastify e o driver oficial do MongoDB. Os montantes são persistidos em uma coleção `batches`; os testes comuns usam um repositório em memória e os testes de integração usam um MongoDB local temporário.

## O que está implementado

- Login com a conta única de demonstração configurada localmente, senha comparada com hash scrypt e JWT válido por uma hora.
- Catálogo fechado dos mesmos dez alimentos das notas e 13 escolas: três entradas originais do protótipo e dez EMEFs públicas de Cariacica–ES, iguais às do Flutter. Fonte: [catálogo de escolas](../docs/ESCOLAS.md).
- Consulta dos itens das duas notas de referência transcritas, sem dados pessoais dos documentos.
- Cadastro e consulta paginada de montantes, com data, alimentos, preços e escolas participantes.
- Distribuição por alimento apenas para escolas participantes. A soma dos pedidos não pode ultrapassar o recebido.
- Confirmação obrigatória do saldo e registro da perda em kg. O restante é sobra aproveitável.
- Relatórios semanais e mensais agrupados por alimento, com valores, perdas, sobras e distribuição por escola.
- Controle de revisão para impedir sobrescrita quando duas pessoas editam o mesmo montante.
- Logs JSON com identificação da requisição, rotas de saúde e limite de requisições e tentativas de login.

A API inicia sem montantes fictícios. Os catálogos e as notas são referências fixas copiadas do projeto, não consultas automáticas às escolas, associações ou serviços de notas fiscais.

**O Flutter usa o login JWT e a sincronização manual desta API.** O botão no Perfil envia edições locais e busca montantes do MongoDB, com cache local e revisão de conflitos. Gráficos e PDFs são calculados no Flutter a partir dessa cópia; não consultam o endpoint de relatórios automaticamente. Veja [sincronização](../docs/SINCRONIZACAO.md).

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

## Demonstração no Railway

Configuração esperada do serviço (os valores do painel não são versionados):

| Opção            | Valor                                                                    |
| ---------------- | ------------------------------------------------------------------------ |
| Root Directory   | `backend`                                                                |
| Build Command    | `npm ci --include=dev && npm run build`                                  |
| Start Command    | `npm start`                                                              |
| Healthcheck Path | `/health/ready`                                                          |
| `NODE_ENV`       | `development` para esta demonstração com conta única                     |
| `HOST`           | `0.0.0.0`                                                                |
| `PORT`           | Utilizar a porta fornecida pelo Railway; o código lê `process.env.PORT`. |

O compilador TypeScript é uma dependência de desenvolvimento, por isso o build instala também essas dependências. O início executa o JavaScript compilado de `dist/server.js`, sem modo watch.

Cadastre `MONGO_URI`, `MONGO_DB_NAME`, `JWT_SECRET`, `MVP_CPF` e `MVP_PASSWORD` nas variáveis privadas do serviço, conforme a tabela de configuração. Arquivos locais de ambiente não são enviados ao GitHub. Autorize a conexão do ambiente de hospedagem no Atlas e configure `CORS_ORIGINS` com as origens HTTPS exatas da interface Web, sem caminho ou barra final.

`NODE_ENV=production` encerra esta API por decisão explícita da configuração atual. Usar `development` permite a demonstração, mas não implementa usuários, permissões ou autenticação apropriados para uso real. A URL pública e as variáveis efetivas do Railway precisam ser conferidas no ambiente publicado; esta seção descreve o contrato esperado, não comprova um deploy.

O Flutter usa `API_BASE_URL` via `--dart-define`, com padrão `https://hackathonif-production.up.railway.app`. Login e sincronização usam a mesma URL. Configure `CORS_ORIGINS` para permitir a interface Web; o servidor permite GET, HEAD, POST e PUT nas origens autorizadas. O APK usa HTTPS e não depende de CORS.

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
| `PUT /v1/batches/:batchId/sync`                           | Cria ou substitui um montante inteiro com revisão, validação atômica e reenvio idempotente.                |
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
- No cadastro por POST, identificadores são UUIDs gerados pelo servidor. `status`, cálculos e datas de criação não podem ser definidos no cadastro pelo cliente.

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

## Sincronização do Flutter

`PUT /v1/batches/:batchId/sync` recebe um UUID v4 gerado pelo cliente **antes** do primeiro envio. O corpo contém os campos do cadastro, `revision` (`null` na criação; número conhecido na atualização) e, em cada alimento, `status`, `requests` e `lossKg`. Alimentos pendentes não podem conter pedidos positivos ou perdas; finalizados exigem classificação da perda. A confirmação do saldo ocorre no formulário Flutter antes de salvar localmente.

O servidor valida o montante inteiro antes de qualquer escrita. A criação é condicional e a atualização compara a revisão atomicamente. Repetir o mesmo conteúdo retorna o registro existente sem incrementar a revisão. Conteúdo diferente com revisão desatualizada retorna 409. Uma atualização com revisão não nula nunca recria silenciosamente um registro removido. A revisão é do montante, não de cada alimento.

## Testes e verificações

```sh
npm run typecheck
npm test
npm run test:integration
npm run build
npm audit --omit=dev
```

Os testes comuns usam injeção HTTP do Fastify e repositório de teste em memória; não acessam o Atlas. Os testes de integração iniciam um processo MongoDB local temporário com `mongodb-memory-server-core`, verificam persistência, índices, filtros e concorrência real e encerram a instância ao terminar. Na primeira execução, essa ferramenta baixa um binário MongoDB e precisa de acesso à Internet e bibliotecas nativas compatíveis.

Para incluir o fluxo com dois clientes Flutter reais via HTTP (a partir da raiz):

```sh
FLUTTER_BIN="$(command -v flutter)" npm run test:integration --prefix backend
```

Esse teste inicia API e MongoDB locais isolados, valida conflito, reinício e reenvio sem duplicação. Sem `FLUTTER_BIN`, esse caso é pulado. Os testes de integração são executados sequencialmente.

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

- Evoluir o cache do MVP e a resolução de conflitos por campo; atualmente o usuário pode preservar a edição local ou substituí-la explicitamente pela versão atual do banco.
- Substituir a conta local de demonstração por usuários persistidos, perfis de acesso e recuperação de senha.
- Definir hospedagem, HTTPS, configuração de proxy e estratégia de backup.
- Revisar as três entradas originais do protótipo e validar com a associação quais escolas públicas cadastradas participam da distribuição.

Referências: [Fastify](https://fastify.dev/docs/latest/), [driver MongoDB](https://www.mongodb.com/docs/drivers/node/current/), [JWT para Fastify](https://github.com/fastify/fastify-jwt), [MongoDB temporário para testes](https://github.com/typegoose/mongodb-memory-server).
