# Validação da demonstração — Nativa 1.0.4+4

> Registro histórico anterior à correção 1.1.0+6. Nessa correção, o login Flutter passou a consultar a API e o Perfil passou a exibir a versão do pacote. Os montantes ainda são locais; consulte o [README atual](../README.md) para configuração e limitações. Os resultados abaixo se referem à revisão identificada neste relatório.

Verificação executada em 19/10/2026, na branch local `chore/validacao-demonstracao-hackathon`, a partir da `develop` (`b1b5b96`, código integrado na `main` pelo merge `b46c088`). Não houve push, merge ou alteração de registros no Atlas/serviço publicado nesta verificação.

## Resultado

**A interface local e a API podem ser demonstradas separadamente. A demonstração integrada Flutter → API → MongoDB ainda não está pronta.** O Flutter instancia `DeliveryRepository` em `lib/main.dart`; seu login valida apenas o formulário e os montantes ficam em memória. Não existe URL de API nem alternância por ambiente ou `--dart-define`. Recarregar a página ou reiniciar o app restaura os exemplos.

## Comandos executados

| Verificação | Resultado |
| --- | --- |
| `flutter pub get` | Dependências resolvidas. Há versões mais novas fora das restrições atuais; não foram atualizadas. |
| `dart analyze` | Nenhuma ocorrência. |
| `flutter test` | 42 testes aprovados, incluindo widgets em 390/1024 pixels, seleção de escolas, limites, sobras/perdas, gráficos e ampliação de fonte. |
| `flutter build web` | Aprovado; arquivos gerados em `build/web`, incluindo dry run Wasm. Aviso não fatal sobre fonte Cupertino ausente, sem referência direta a `CupertinoIcons` no código do app. |
| `flutter build apk --release` | Aprovado; APK de 60,7 MB, versão Android 1.0.4, código 4, conferidos com `aapt`. |
| `npm run typecheck --prefix backend` | Aprovado. |
| `npm test --prefix backend` | 16 testes aprovados. |
| `npm run test:integration --prefix backend` | 2 testes aprovados com MongoDB local temporário, separado do Atlas. |
| `npm run build --prefix backend` | Aprovado. |
| `npm run format:check --prefix backend` | Aprovado. |

Ambiente: Flutter 3.47.7/Dart 3.13.5, Node 22.23.1, Android SDK 36 e JDK 21. O `flutter doctor -v` reconheceu a ferramenta Android e suas licenças; não encontrou Chrome nem aparelho Android. A ferramenta Linux está incompleta e o projeto não possui plataforma Linux. iOS exige macOS/Xcode e não foi compilado aqui.

## Execução pela interface Web

O build Web desta revisão foi servido localmente e aberto em Chromium headless instalado separadamente para a validação, em viewport de 390 × 844 pixels. A automação confirmou:

- Login vazio exibe erro de validação; dados fictícios aceitos pelo login local abrem o início.
- Navegação para Produtos e Relatórios, com acionamento do filtro semanal.
- Recarga retorna ao login.
- Zero erros JavaScript não tratados e zero requisições a `/v1/` durante esse percurso, consistente com a ausência de integração identificada no código.

Capturas de login, Produtos e Relatórios foram inspecionadas localmente. Isso é um teste de navegador desktop com viewport móvel, não uma execução em celular. Cadastro e classificação pela interface foram exercitados pelos testes de widgets; não foram repetidos no navegador. Geração de PDF foi exercitada no teste de domínio Flutter, mas abertura/compartilhamento em um leitor externo ainda precisa de teste manual.

## API publicada

Endereço testado: <https://hackathonif-production.up.railway.app>.

| Requisição | Resultado observado |
| --- | --- |
| `GET /health/live` | 200, `status=ok`. |
| `GET /health/ready` | 200, `database=available`. |
| `POST /v1/auth/login`, credencial válida disponível no ambiente local | 200; JWT obtido sem exibi-lo. |
| `POST /v1/auth/login`, senha inválida | 401. |
| `GET /v1/batches?limit=1`, sem token | 401. |
| Mesma consulta com token inválido | 401. |
| Mesma consulta com token válido | 200. Nenhum conteúdo de registros foi incluído neste relatório. |
| `GET /v1/auth/me`, token válido | 200. |
| `GET /v1/catalog/foods`, token válido | 200. |

Esses resultados comprovam disponibilidade, autenticação e leitura no momento do teste. Não comprovam que o deploy corresponde exatamente ao commit local, pois a API não expõe identificação da versão publicada.

## Fluxo em ambiente exclusivo de teste

O novo `backend/tests/integration/demo-flow.test.ts` inicia um MongoDB temporário, abre uma API HTTP em porta efêmera e usa uma conta fictícia exclusiva dos testes. Não lê a URI do Atlas.

- Cadastro HTTP de um montante com Aipim (100 kg) e escolas IFES/Darllin: 201. Consulta: 200.
- Quantidades negativas no recebimento, pedido e perda: 400.
- Soma dos pedidos de 110 kg para 100 kg recebidos: 422, `STOCK_EXCEEDED`.
- Saldo sem confirmação/classificação: 422, `BALANCE_CONFIRMATION_REQUIRED`.
- Perda acima do saldo: 422, `INVALID_LOSS`.
- Após cada rejeição, consulta confirmou revisão zero e alimento pendente, sem gravação parcial.
- Rateio válido: 60 kg distribuídos, 10 kg de perda e 30 kg de sobra; status finalizado.
- API e conexão MongoDB encerradas; outra instância e conexão abertas, com novo login/token. A consulta retornou exatamente o montante salvo e o relatório confirmou os totais.
- Preflight CORS da origem de teste autorizada: 204 com origem correta. Isso não valida a origem real de um futuro site.

O teste de integração anterior também passou, incluindo persistência, filtros e conflito de gravações concorrentes.

## Railway

O código usa `process.env.PORT` e respeitou uma porta de teste fornecida pelo processo. `HOST=0.0.0.0` foi aceito pela configuração. `PORT` inválida foi rejeitada. `NODE_ENV=production` foi executado e confirmou o bloqueio explícito da conta única.

Configuração esperada, agora documentada no README do backend:

- Root Directory: `backend`.
- Build: `npm ci --include=dev && npm run build` (TypeScript está nas dependências de desenvolvimento).
- Start: `npm start`, que executa `node dist/server.js`.
- Healthcheck: `/health/ready`.
- Demonstração atual: `NODE_ENV=development`, `HOST=0.0.0.0`, porta fornecida pelo Railway.
- Variáveis privadas: `MONGO_URI`, `MONGO_DB_NAME`, `JWT_SECRET`, `MVP_CPF`, `MVP_PASSWORD`; `CORS_ORIGINS` deve conter as origens exatas do site quando houver integração Web.

Não há configuração Railway versionada nem acesso ao painel nesta verificação. Os valores efetivos de Root Directory, comandos, origem CORS e variáveis do serviço não puderam ser inspecionados. A API pública respondeu aos testes acima; isso não substitui a inspeção dessas configurações.

## Alterações e falhas

- Adicionado teste do fluxo HTTP completo, cobrindo validações e persistência após reinício da API/conexão, antes ausente.
- Documentados comandos e configuração esperados para a demonstração no Railway.
- Houve timeout de 10 segundos ao iniciar os processos MongoDB temporários durante as compilações. O script de integração foi ajustado para executar os arquivos sequencialmente; a repetição após as compilações passou (2/2). Não foi observado erro de regra de negócio nessa falha de inicialização.
- Nenhuma alteração de autenticação ou integração Flutter foi feita: a ausência de integração é uma limitação confirmada desta versão, não um fluxo aprovado.

## Pendências e uso real

- Testar no celular: instalar APK, teclado, rolagem, voltar do Android, rotação, fontes do sistema/ampliação e abrir/compartilhar PDF com os aplicativos do aparelho.
- Validar iOS em macOS/Xcode se for utilizado.
- Integrar login JWT, repositório HTTP, tratamento de falhas/sessão expirada e configuração explícita da URL por ambiente antes de demonstrar persistência pelo app.
- O backend possui somente uma conta de demonstração, sem usuários persistidos, permissões, recuperação de senha, revogação ou renovação do token; JWT expira em uma hora.
- O Flutter permite acesso apenas pela validação local do formulário. Ele não testa a senha do backend.
- Escolas ainda são provisórias. Não há isolamento entre associações, comprovação de entrega física ou emissão fiscal.
- O APK usa identificador de exemplo e assinatura de depuração; não está preparado para distribuição em loja.
- Preferências de fonte e dados Flutter não persistem entre reinícios. O teste de persistência aprovado é da API isolada.
