# Nativa

Protótipo Flutter para organizar montantes de alimentos e calcular sua distribuição entre escolas, com foco inicial na associação **Aprovista**.

Versão: **1.1.0+5**, conforme o [pubspec.yaml](pubspec.yaml). O histórico de mudanças está no [CHANGELOG.md](CHANGELOG.md).

## Problema, público-alvo e solução

O [escopo inicial](anotacoes.txt) descreve alimentos recebidos em montantes e a necessidade de dividi-los entre escolas a partir dos pedidos feitos pela nutricionista. Quando a quantidade recebida é menor que a soma dos pedidos, a pessoa responsável pela distribuição precisa definir quanto cada escola receberá e acompanhar as pendências.

O Nativa é voltado às pessoas que organizam essa distribuição em associações. A proposta é reunir os alimentos de cada montante, registrar os pedidos das escolas e calcular um rateio proporcional, mantendo visíveis os totais, as sobras, as faltas e os status.

**O aplicativo Flutter atual é uma demonstração local.** Os exemplos de montantes, alimentos, escolas e perfil são carregados pelo código e ficam em memória. Os cálculos e formulários funcionam localmente, mas não há conexão com serviços de associações ou escolas. Reiniciar o app ou recarregar a página restaura os dados de exemplo.

O [backend TypeScript](backend/README.md) já possui uma API REST com autenticação JWT de demonstração, persistência MongoDB, montantes, distribuição e relatórios por alimento. Ele é executado separadamente e ainda não está conectado ao Flutter. A conexão ao Atlas depende de `MONGO_URI` válida no ambiente local.

## Funcionalidades implementadas

- **Acesso de demonstração:** formulário com CPF de 11 dígitos, campo de senha obrigatório e opção de mostrar ou ocultar o texto. Não há autenticação real nem validação dos dígitos verificadores do CPF.
- **Início:** calendário com navegação por mês e seleção de dia, montantes pendentes e histórico recente. Os cards de alimentos, escolas e distribuição aparecem somente ao abrir um montante, com informações em pop-ups.
- **Cadastro de montantes:** nome, data, seleção obrigatória de pelo menos uma escola participante do cadastro definido, alimentos selecionados do catálogo fechado, quantidade em kg, preço por kg e nota de referência opcional. O catálogo contém somente os 10 alimentos distintos das duas notas fornecidas, incluindo as variedades orgânicas.
- **Consulta de montantes:** busca por nome, alimento ou escola e filtros de pendentes e finalizados.
- **Divisão por alimento:** apenas os pedidos em kg são editáveis. Aparecem apenas as escolas selecionadas no montante, sem edição dos nomes; um campo em branco representa ausência de pedido daquele alimento. A escolha vale para todos os alimentos do montante e é preservada ao salvar o rateio.
- **Validação dos pedidos:** quantidades em unidades de 0,1 kg e bloqueio quando a soma dos pedidos ultrapassa o recebido, com aviso do excesso. A regra é aplicada no formulário e na camada de dados.
- **Acompanhamento do rateio:** detalhes por escola e atualização dos status ao salvar. Se houver saldo, uma confirmação bloqueia a tela até cancelar ou confirmar; depois, é necessário informar quanto foi sobra aproveitável e quanto foi perda.
- **Dashboard de produtos:** agrupamento de lotes por nome de produto, totais recebidos, rateados e sem rateio, busca, filtros por status e acesso aos detalhes dos lotes. Os três indicadores abrem o catálogo, os recebimentos por produto e os rateios por escola.
- **Relatórios:** gráficos de pizza do destino dos alimentos, colunas de recebido e distribuído por alimento e barras horizontais por escola; filtros semanal e mensal, distribuição por escola, quantidades recebidas, pendências, sobras, perdas e taxa de perdas. A tela e o PDF consolidam os recebimentos por alimento, com quantidades, valores e distribuição por escola. Os valores somam os preços de cada recebimento; subtotais com preços ausentes ficam sinalizados como parciais. O PDF usa tabelas sem gráficos e pode ser visualizado, baixado ou impresso.
- **Notas de referência:** itens, preços e totais transcritos de duas DANFEs fornecidas, separados dos totais dos montantes para evitar dupla contagem.
- **Perfil:** dados fixos de demonstração com opção de sair.
- **Interface em português do Brasil:** navegação inferior em telas menores e lateral em telas maiores.
- **Tamanho das letras:** controles no topo, disponíveis desde o login, para aumentar em etapas de 20% até 200%, diminuir ou restaurar o tamanho do aparelho. O ajuste vale também para detalhes e pop-ups, respeita a configuração de fonte do sistema e permanece durante a sessão. Recarregar a página ou reiniciar o app restaura o padrão do aparelho.

Um **montante** reúne vários alimentos. Cada alimento é registrado como um **lote** com seus pedidos e quantidades rateadas. Salvar o rateio finaliza esse alimento; o montante fica finalizado quando todos os seus alimentos estão finalizados. Esse status representa o registro do rateio, sem comprovar uma entrega física.

A soma dos pedidos deve ser menor ou igual à quantidade recebida. Se exceder, o usuário precisa revisar os pedidos antes de salvar. Quando há saldo, ele deve ser classificado como sobra aproveitável ou perda. O cálculo em unidades de 0,1 kg está em [proportional_allocation.dart](lib/domain/proportional_allocation.dart). Os gráficos usam os dados do período selecionado; os detalhamentos por alimento podem ser expandidos na tela.

## Tecnologias e dependências

As dependências diretas estão declaradas no [pubspec.yaml](pubspec.yaml).

| Tecnologia ou dependência | Função no projeto |
| --- | --- |
| Dart | Modelos, regras de rateio e lógica do aplicativo. O projeto declara a restrição de SDK `^3.12.0`. |
| Flutter e Material 3 | Interface compartilhada para Web, Android e iOS, com layouts adaptados à largura disponível. |
| `flutter_localizations` | Localização dos componentes do Flutter para `pt_BR`. |
| `ChangeNotifier` e `ListenableBuilder` | Recursos do Flutter usados para atualizar a interface quando os dados mudam, sem pacote externo de gerenciamento de estado. |
| `pdf` e `printing` | Geração dos relatórios em PDF, visualização, compartilhamento e impressão. A prévia Web pode carregar Pdf.js pela internet. |
| `flutter_test` | Testes de regras de negócio, ViewModel e interações com widgets. |
| `flutter_lints` `^5.0.0` | Regras de análise estática, complementadas pelas opções estritas do projeto. |
| `flutter_launcher_icons` `^0.14.4` | Ferramenta de desenvolvimento para gerar os ícones de Android, iOS e Web a partir das imagens da marca. |

A organização separa interface, estado, domínio e acesso aos dados. O [DeliveryViewModel](lib/ui/view_models/delivery_view_model.dart) expõe os dados para as telas, e o [DeliveryRepository](lib/data/delivery_repository.dart) mantém os registros em memória. O Flutter ainda não consome a API. O backend independente em [backend/](backend/README.md) usa MongoDB para persistir os montantes e possui login JWT com uma conta local de demonstração.

## Pré-requisitos e instalação

- Flutter no canal estável, com o Dart incluído no SDK, e os comandos `flutter` e `dart` disponíveis no terminal.
- Uma ferramenta de execução configurada para a plataforma desejada, conforme a tabela abaixo.
- Acesso à internet para baixar as dependências na instalação inicial.

O ambiente desta revisão utiliza **Flutter 3.47.7 e Dart 3.13.5**. As dependências de PDF exigem Dart a partir de 3.12.0 e Flutter a partir de 3.41.0, agora declarados no `pubspec.yaml`. Para reproduzir o ambiente validado, utilize Flutter 3.47.7 com o Dart incluído nesse SDK.

Após obter uma cópia do repositório, entre na pasta e instale as dependências:

```sh
cd hackathonif
flutter doctor
flutter pub get
flutter devices
```

| Plataforma configurada | Requisitos específicos |
| --- | --- |
| Web | Navegador; Chrome para o destino `chrome`, ou um navegador acessando o servidor de desenvolvimento. |
| Android | Android SDK, JDK compatível com a configuração Gradle e um emulador ou aparelho conectado. Os alvos Java e Kotlin estão configurados como 17. |
| iOS | macOS com Xcode e as ferramentas iOS configuradas para Flutter, além de simulador ou aparelho. O projeto define iOS 15.0 como alvo mínimo. |

Existem projetos de plataforma em [web/](web/), [android/](android/) e [ios/](ios/). Não há projetos nativos para Linux, Windows ou macOS neste repositório.

## Executar

### Web

Com Chrome instalado e reconhecido pelo Flutter:

```sh
flutter run -d chrome
```

Como alternativa, inicie o servidor de desenvolvimento e abra o endereço informado pelo terminal no navegador:

```sh
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

Para gerar os arquivos estáticos da versão Web:

```sh
flutter build web
```

A saída fica em `build/web/`. Esse comando gera os arquivos; ele não publica o aplicativo em um serviço de hospedagem.

### Android e iOS

Inicie um emulador, simulador ou conecte um aparelho. Execute `flutter devices` e substitua o identificador no comando correspondente pelo ID listado:

```sh
# Android
flutter run -d ID_ANDROID

# iOS, em macOS
flutter run -d ID_IOS
```

As configurações nativas estão presentes, mas a execução em Android e iOS não foi validada nesta revisão. Esses comandos dependem da configuração local das ferramentas e dos dispositivos.

### Acesso para demonstração

Use dados fictícios: a tela exige 11 dígitos no campo CPF e preenchimento do campo de senha. Não há conta cadastrada, credencial fixa ou consulta a um servidor. O botão de recuperação de senha apenas informa que o serviço ainda precisa ser integrado.

## Configurações

O Flutter ainda não exige `.env`, variáveis de ambiente próprias, chaves de API ou configuração de backend. A API TypeScript usa configuração própria, descrita em [backend/README.md](backend/README.md). Os exemplos são definidos em [delivery_repository.dart](lib/data/delivery_repository.dart), e o tema e os formatos de exibição estão em [theme.dart](lib/ui/theme.dart).

A logo utilizada nas telas está em [assets/images/nativa_logo.png](assets/images/nativa_logo.png). O arquivo [assets/images/nativa_launcher.png](assets/images/nativa_launcher.png) é a base dos ícones, conforme a configuração `flutter_launcher_icons` no `pubspec.yaml`. Para regenerá-los, após instalar as dependências:

```sh
dart run flutter_launcher_icons
```

Essa ferramenta modifica os arquivos de ícones das plataformas e só é necessária ao atualizar a marca.

Os catálogos ficam em [catalog.dart](lib/domain/catalog.dart), e os itens das notas em [invoice_reference.dart](lib/domain/invoice_reference.dart). Os PDFs usam fontes locais para preservar acentos; a licença das fontes está em [Roboto_LICENSE.txt](assets/fonts/Roboto_LICENSE.txt). Os documentos originais não são distribuídos com o aplicativo.

## Backend TypeScript

A configuração e os contratos HTTP estão em [backend/README.md](backend/README.md). Requer Node.js 22.13 ou superior e MongoDB Atlas configurado. O backend possui dependências e lockfile próprios em [backend/package.json](backend/package.json).

```sh
cd backend
npm ci
# Configure backend/.env conforme o README do backend.
npm run db:check
npm run dev
```

A conta MVP é configurada localmente por `MVP_CPF` e `MVP_PASSWORD`. JWTs são assinados com `JWT_SECRET`. A API oferece rotas de saúde, login, catálogos, montantes, distribuição com revisão e relatórios semanais/mensais por alimento. O MongoDB não recebe dados fictícios automaticamente.

Para validar a API, execute dentro de `backend/`: `npm run typecheck`, `npm test`, `npm run test:integration` e `npm run build`. Os testes de integração usam um MongoDB local temporário, separado do Atlas. Nenhuma credencial do ambiente deve ser versionada.

## Estrutura de pastas

```text
backend/                    API TypeScript, configuração, documentação e testes
lib/
  main.dart                 Inicialização, tema, localização e acesso de demonstração
  data/                     Repositório com dados de exemplo e armazenamento em memória
  domain/                   Modelos, agrupamentos e cálculo proporcional
  ui/
    screens/                Início, montantes, formulários, produtos e detalhes
    view_models/            Estado e operações usados pelas telas
    theme.dart              Cores, marca e formatação de datas e pesos
test/
  domain/                   Testes de rateio e agrupamento
  ui/screens/               Testes de acesso e fluxos em telas menores e maiores
  ui/view_models/           Testes de totais, pedidos e status
assets/images/              Imagens da marca
assets/fonts/               Fontes Roboto incorporadas ao PDF e licença da fonte
android/                    Projeto nativo Android
ios/                        Projeto nativo iOS
web/                        Página de entrada, manifesto e ícones Web
```

O [anotacoes.txt](anotacoes.txt) registra o escopo inicial, e o [analysis_options.yaml](analysis_options.yaml) define as regras de análise de código.

## Testes e análise de código

Após `flutter pub get`, execute na raiz do projeto:

```sh
dart analyze
flutter test
```

Para executar apenas os testes da regra de rateio:

```sh
flutter test test/domain/proportional_allocation_test.dart
```

Os testes verificam, entre outros casos, estoque insuficiente, sobra, arredondamento, um cenário com 50 escolas, agrupamentos, atualização dos status, cadastro de montantes e o fluxo de divisão entre escolas. Os testes de widgets usam larguras de 390 e 1024 pixels; isso não equivale a testes em aparelhos físicos.

Nesta revisão, a análise estática terminou sem ocorrências, os testes Flutter passaram e `flutter build web` gerou os arquivos da aplicação com sucesso. A execução em navegador e as compilações nativas não foram verificadas nesta revisão.

## Limitações atuais

- No Flutter, os registros ainda existem apenas em memória, sem sincronização com o backend ou persistência entre reinicializações. A API possui persistência MongoDB, mas precisa de conexão Atlas válida e integração com o app.
- O acesso, o perfil e os dados iniciais são de demonstração. Não há contas, permissões por função ou recuperação de senha real.
- O recorte implementado é a Aprovista; não há seleção nem isolamento de dados entre associações.
- O PDF é um relatório gerencial de alimentos e valores, não uma nota fiscal. Não há emissão fiscal, importação automática de novas notas, envio de fotos ou comprovantes assinados.
- O catálogo de alimentos foi definido a partir das notas fornecidas. As três escolas ainda são as do protótipo e precisam ser substituídas pelo cadastro oficial.
- Os valores representam alimentos recebidos e sua destinação; não são receitas, pagamentos, lucro ou saldo bancário. Lotes sem preço são destacados e não integram o subtotal financeiro.
- Os filtros usam a data do montante para a operação e a data de emissão para as notas. A taxa de perdas corresponde a kg perdidos divididos pelos kg recebidos no período, incluindo o estoque que ainda aguarda rateio.
- O status finalizado indica rateio salvo. Não existe confirmação de recebimento pelas escolas nem rastreamento de entregas.
- As quantidades são tratadas em kg e o cálculo usa unidades de 0,1 kg. Não há conversão para litros, unidades ou outras medidas.
- O projeto nativo ainda usa identificadores de exemplo. No Android, a configuração de release usa a assinatura de depuração; o projeto requer preparação para distribuição em lojas.
- Não há registro no repositório que comprove validação operacional com a associação ou resultados de uso em produção.

## Próximos passos propostos

- Integrar o Flutter à API MongoDB e substituir a conta única do backend por usuários persistidos e regras de acesso.
- Validar o fluxo de pedidos, rateio e confirmação de entregas com a Aprovista.
- Estruturar cadastros e permissões para outras associações citadas no escopo, como Aprucas, Aproder e CAFC.
- Integrar novas notas e comprovantes após definir armazenamento e regras operacionais.
- Validar a execução em Android e iOS e preparar identificadores, assinatura e distribuição.

Esses itens são propostas de evolução, não recursos disponíveis no protótipo.

## Desenvolvimento e versões

O fluxo definido para o projeto usa `develop` como integração e base para `feature/<nome>`. As funcionalidades retornam à `develop` por pull request; a `main` recebe versões após validação. Correções urgentes de versões publicadas usam `hotfix/<nome>` a partir da `main`, com integração também na `develop`. Commits feitos em conjunto registram a autoria adicional com trailers `Co-authored-by`.

A versão segue `MAJOR.MINOR.PATCH+BUILD` no [pubspec.yaml](pubspec.yaml): `MINOR` para novas funcionalidades, `PATCH` para correções e `MAJOR` para mudanças incompatíveis após a versão estável 1.0.0. Durante a fase `0.x`, novas versões menores também podem conter mudanças incompatíveis. O número `BUILD` cresce a cada versão distribuída nas lojas.

Atualize o [CHANGELOG.md](CHANGELOG.md) ao preparar uma versão. Antes de integrar uma release na `main`, valide o aplicativo e execute os testes e a análise estática. As releases usam tags anotadas no formato `vMAJOR.MINOR.PATCH`. A versão atual está registrada no changelog; o sufixo `+5` identifica o build Android 5.
