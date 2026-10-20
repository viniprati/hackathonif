# Histórico de versões

## Backend — em desenvolvimento

- API REST TypeScript com Fastify, login JWT de demonstração e persistência MongoDB.
- Catálogos definidos, montantes com escolas participantes, distribuição com revisão e relatórios por alimento.
- Validação dos pedidos, classificação de saldo, logs estruturados e rotas de saúde.
- Testes HTTP e de regras, com integração em MongoDB local temporário.
- Integração do Flutter com a API pendente; credenciais mantidas em arquivos locais ignorados pelo Git.

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
