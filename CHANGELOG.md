# Histórico de versões

## 1.2.1+11 — 20/10/2026

- Preserva classes Kotlin acessadas por JNI na otimização do APK release, corrigindo a abertura do armazenamento local após o login.
- Botão de tentar novamente corrigido para atualizar o estado sem retornar um Future ao Flutter.
- Diagnóstico seguro distingue falhas na leitura do armazenamento e no formato do cache, sem registrar seu conteúdo.
- Teste de integração nativa para ler, gravar e restaurar montantes com o plugin real de armazenamento.

## 1.2.0+10 — 20/10/2026

- Versão menor incrementada para identificar a nova funcionalidade de sincronização manual introduzida no build 9.
- Backend alinhado à versão 1.2.0 e build Android incrementado para 10, permitindo atualização sobre o APK anterior.

## 1.1.0+9 — 20/10/2026

- Sincronização manual pelo Perfil: envio dos montantes e rateios e consulta aos dados compartilhados do MongoDB.
- Cache local de rascunhos e revisões, sem credenciais; aplicativo real inicia sem montantes fictícios.
- Revisão de conflitos entre aparelhos, gravação atômica por montante e reenvio idempotente após perda de resposta.
- CORS permite PUT nas origens Web autorizadas.
- Testes de sincronização, interface e fluxo com dois clientes Flutter via HTTP e MongoDB temporário.

## 1.1.0+8 — 20/10/2026

- Dez EMEFs públicas de Cariacica–ES adicionadas aos catálogos Flutter e backend, com nomes e bairros conferidos na lista da Prefeitura.
- As três entradas originais foram mantidas, totalizando 13 opções. Os montantes de exemplo mantêm suas escolas participantes.
- Fonte e lista em [docs/ESCOLAS.md](docs/ESCOLAS.md).

## 1.1.0+7 — 19/10/2026

- Cadastro de montantes sem seleção ou vínculo de nota fiscal. Preços por kg continuam editáveis e os alimentos disponíveis vêm do catálogo completo.

## 1.1.0+6 — 19/10/2026

- Login Flutter integrado ao backend: autenticação JWT, rejeição de credenciais inválidas, estados de carregamento/erro e encerramento de sessão ao sair ou expirar.
- URL de API configurável por `API_BASE_URL`, com padrão apontando para o Railway da demonstração. Permissão de internet incluída no Android release.
- Perfil consulta a versão real do pacote instalado em vez de exibir texto fixo. Build Android incrementado para 6.
- Testes de autenticação HTTP e da interface, incluindo senha incorreta e versão do pacote.
- Os montantes e relatórios do Flutter continuam locais em memória; somente o login foi integrado nesta correção.

## 1.1.0+5 — 19/10/2026

- API REST TypeScript com Fastify, login JWT de demonstração e persistência MongoDB.
- Catálogos definidos, montantes com escolas participantes, distribuição com revisão e relatórios por alimento.
- Validação dos pedidos, classificação de saldo, logs estruturados e rotas de saúde.
- Testes HTTP e de regras, com integração em MongoDB local temporário.
- Integração do Flutter com a API pendente; credenciais mantidas em arquivos locais ignorados pelo Git.

- Validação da demonstração com 42 testes Flutter e 18 testes backend, builds Web/Android e verificações da API publicada. Evidências referentes ao código antes da atualização de versão estão em [docs/VALIDACAO_DEMONSTRACAO.md](docs/VALIDACAO_DEMONSTRACAO.md).
- Teste HTTP de persistência após reiniciar API e conexão MongoDB; testes de integração executados sequencialmente.
- Documentação da configuração de demonstração no Railway. Backend versionado como 1.1.0; Flutter como 1.1.0+5.
- Esta versão mantém o Flutter com dados em memória, sem integração HTTP com a API.

## 1.0.4+4 — 19/10/2026

- Indicadores de produtos com abertura dos detalhes pelo card inteiro, sem hyperlink.

- Seleção das escolas participantes no cadastro do montante, com lista filtrada nos detalhes e no rateio de todos os alimentos.
- Validação impede pedidos de escolas não participantes e preserva a seleção ao salvar e reabrir a distribuição.

## 1.0.2+3 — 19/10/2026

- Relatórios na tela e no PDF agrupados por alimento, com soma dos recebimentos, valores parciais e distribuição por escola. PDF em tabelas sem gráficos.

- Indicadores de produtos clicáveis, com detalhamento de produtos, recebimentos e rateios por escola.
- Bloqueio de pedidos cuja soma ultrapassa o recebido, no formulário e na camada de dados.
- Relatórios com gráficos de pizza, colunas por alimento e barras por escola, com valores e alimentos em seções expansíveis.

## 1.0.1+2 — 19/10/2026

- Controles globais de tamanho das letras, com ampliação até 200% e respeito à fonte do aparelho; calendário e indicadores adaptados para leitura ampliada.
- Protótipo Flutter da Nativa com login de demonstração.
- Cadastro de lotes e rateio proporcional de alimentos por escola.
- Lista e detalhe das entregas, documentos e perfil.
- Tela inicial com calendário, filtro por dia e painel de atividades.
- Dashboard de produtos com totais, busca e acesso aos lotes.
- Fluxo de montantes com vários alimentos, busca, filtros e rateio por escola com saldo visível.

- Catálogo fechado com os alimentos das notas; escolas fixas e pedidos opcionais.
- Confirmação obrigatória do saldo e classificação de sobra e perda.
- Relatórios semanais e mensais com valores, taxa de perdas e PDF gerencial.

Versão preparada para integração na `main`, com tag `v1.0.1` e build Android 2.
