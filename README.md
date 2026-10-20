# Nativa

Protótipo Flutter para organizar montantes de alimentos e calcular sua distribuição entre escolas, com foco inicial na associação **Aprovista**.

Versão: **1.2.1+11**, conforme o [pubspec.yaml](pubspec.yaml). O histórico de mudanças está no [CHANGELOG.md](CHANGELOG.md).

## Problema, público-alvo e solução

O [escopo inicial](anotacoes.txt) descreve alimentos recebidos em montantes e a necessidade de dividi-los entre escolas a partir dos pedidos feitos pela nutricionista. Quando a quantidade recebida é menor que a soma dos pedidos, a pessoa responsável pela distribuição precisa definir quanto cada escola receberá e acompanhar as pendências.

O Nativa é voltado às pessoas que organizam essa distribuição em associações. A proposta é reunir os alimentos de cada montante, registrar os pedidos das escolas e calcular um rateio proporcional, mantendo visíveis os totais, as sobras, as faltas e os status.

**O Flutter autentica e sincroniza montantes com a API real.** Em **Perfil → Sincronizar dados**, envia os montantes e rateios editados neste aparelho e busca os dados compartilhados do MongoDB. A atualização é manual. O aplicativo inicia sem montantes fictícios; os catálogos e o perfil continuam referências definidas no código.

A cópia de trabalho local é restaurada ao reabrir o app, após o login. Se duas pessoas editarem o mesmo montante, o app preserva a edição local e apresenta as duas versões para revisão. Consulte o [fluxo de sincronização e suas limitações](docs/SINCRONIZACAO.md).

## Funcionalidades implementadas

- **Acesso pela API:** CPF de 11 dígitos e senha são enviados via HTTPS ao backend. O app só abre após receber uma sessão JWT válida, informa credenciais inválidas/falhas de conexão e impede envio duplicado durante a autenticação. A conta única é configurada pelo servidor; não há senha embutida no APK. O token fica em memória e a sessão encerra ao sair, reiniciar ou expirar. Não há validação dos dígitos verificadores do CPF fictício de demonstração.
- **Início:** calendário com navegação por mês e seleção de dia, montantes pendentes e histórico recente. Os cards de alimentos, escolas e distribuição aparecem somente ao abrir um montante, com informações em pop-ups.
- **Cadastro de montantes:** nome, data, seleção obrigatória de pelo menos uma escola participante do cadastro definido, alimentos selecionados do catálogo fechado, quantidade em kg e preço por kg editável, sem vínculo com nota fiscal. O catálogo contém somente os 10 alimentos distintos das duas notas fornecidas, incluindo as variedades orgânicas.
- **Consulta de montantes:** busca por nome, alimento ou escola e filtros de pendentes e finalizados.
- **Divisão por alimento:** apenas os pedidos em kg são editáveis. Aparecem apenas as escolas selecionadas no montante, sem edição dos nomes; um campo em branco representa ausência de pedido daquele alimento. A escolha vale para todos os alimentos do montante e é preservada ao salvar o rateio.
- **Validação dos pedidos:** quantidades em unidades de 0,1 kg e bloqueio quando a soma dos pedidos ultrapassa o recebido, com aviso do excesso. A regra é aplicada no formulário e na camada de dados.
- **Acompanhamento do rateio:** detalhes por escola e atualização dos status ao salvar. Se houver saldo, uma confirmação bloqueia a tela até cancelar ou confirmar; depois, é necessário informar quanto foi sobra aproveitável e quanto foi perda.
- **Dashboard de produtos:** agrupamento de lotes por nome de produto, totais recebidos, rateados e sem rateio, busca, filtros por status e acesso aos detalhes dos lotes. Os três indicadores abrem o catálogo, os recebimentos por produto e os rateios por escola.
- **Relatórios:** gráficos de pizza do destino dos alimentos, colunas de recebido e distribuído por alimento e barras horizontais por escola; filtros semanal e mensal, distribuição por escola, quantidades recebidas, pendências, sobras, perdas e taxa de perdas. A tela e o PDF consolidam os recebimentos por alimento, com quantidades, valores e distribuição por escola. Os valores somam os preços de cada recebimento; subtotais com preços ausentes ficam sinalizados como parciais. O PDF usa tabelas sem gráficos e pode ser visualizado, baixado ou impresso.
- **Notas de referência:** itens, preços e totais transcritos de duas DANFEs fornecidas, separados dos totais dos montantes para evitar dupla contagem.
- **Perfil:** dados fixos de demonstração, saída e sincronização manual com indicador de pendências, última atualização e revisão de conflitos. Montantes sincronizados alimentam também Produtos, gráficos e PDFs locais.
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
| `http` | Login e sincronização autenticada com a API REST. |
| `shared_preferences` | Cache dos montantes, rascunhos e revisões por endereço da API; não armazena credenciais nem token. |
| `uuid` | Identificador estável antes do primeiro envio, para evitar duplicações ao repetir uma requisição. |
| `package_info_plus` | Consulta a versão e o número do build do aplicativo instalado, exibidos no Perfil. |
| `pdf` e `printing` | Geração dos relatórios em PDF, visualização, compartilhamento e impressão. A prévia Web pode carregar Pdf.js pela internet. |
| `flutter_test` | Testes de regras de negócio, ViewModel e interações com widgets. |
| `integration_test` | Teste nativo de leitura, gravação e abertura do cache após login, em aparelho/emulador de teste. |
| `flutter_lints` `^5.0.0` | Regras de análise estática, complementadas pelas opções estritas do projeto. |
| `flutter_launcher_icons` `^0.14.4` | Ferramenta de desenvolvimento para gerar os ícones de Android, iOS e Web a partir das imagens da marca. |

A organização separa interface, estado, domínio e acesso aos dados. O [DeliveryViewModel](lib/ui/view_models/delivery_view_model.dart) expõe o repositório de trabalho para as telas. O [ManualSync](lib/data/manual_sync.dart) coordena cache, comparação de revisões e envio pela [BatchApi](lib/data/batch_api.dart), usando a sessão do [AuthRepository](lib/data/auth_repository.dart). O [backend](backend/README.md) valida e persiste os montantes no MongoDB.

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

Use a conta de demonstração configurada nas variáveis privadas `MVP_CPF` e `MVP_PASSWORD` do backend. O app verifica as credenciais na API e precisa de internet. Não existe mais acesso com qualquer CPF/senha. A recuperação de senha orienta procurar a equipe; não há fluxo automático.

## Configurações

O Flutter usa `API_BASE_URL` em tempo de compilação. O padrão é `https://hackathonif-production.up.railway.app`; não coloque credenciais nesse valor. Para outro servidor HTTPS, informe `--dart-define=API_BASE_URL=https://sua-api.example.com`. Em desenvolvimento, localhost e `10.0.2.2` podem usar HTTP; no APK release prefira HTTPS, pois as políticas nativas podem bloquear HTTP.

```sh
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
flutter build apk --release --dart-define=API_BASE_URL=https://hackathonif-production.up.railway.app
```

Para Web, configure `CORS_ORIGINS` no backend com a origem exata do site/servidor local. Sem essa liberação o navegador bloqueia o login; não há fallback local. Não é necessário colocar `.env`, JWT_SECRET ou URI do MongoDB no Flutter. A API TypeScript usa configuração própria, descrita em [backend/README.md](backend/README.md). Os exemplos são definidos em [delivery_repository.dart](lib/data/delivery_repository.dart), e o tema e os formatos de exibição estão em [theme.dart](lib/ui/theme.dart).

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
  data/                     Repositórios, API autenticada, cache e sincronização manual
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

Para executar também o cliente Flutter real contra HTTP e MongoDB temporário, sem usar o Atlas:

```sh
FLUTTER_BIN="$(command -v flutter)" npm run test:integration --prefix backend
```

Sem `FLUTTER_BIN`, essa integração específica é pulada pelo backend. `flutter test` sozinho pula o teste que depende dessa API temporária. As verificações cobrem dois clientes, persistência, conflitos e reenvio após perda de resposta; testes de widgets não substituem a validação em celular físico.

Para verificar o armazenamento nativo e a abertura após login em Android otimizado, com um aparelho/emulador de teste conectado:

```sh
cd android
./gradlew app:connectedReleaseAndroidTest -PtestRelease -Ptarget="$(pwd)/../integration_test/local_cache_test.dart"
cd ..
```

Esse teste usa o plugin real de armazenamento com chave exclusiva e login HTTP simulado, sem consultar ou alterar o banco da demonstração. Execute em um aparelho/emulador de teste: o pacote de teste substitui a instalação desse identificador. Após testar, gere novamente o aplicativo normal com `flutter build apk --release`.

## Limitações atuais

- A sincronização exige ação no Perfil e conexão com a API. Não há atualização em tempo real ou em segundo plano. O cache local é uma conveniência, não um backup: limpeza de dados, desinstalação ou falha de armazenamento pode perder rascunhos ainda não enviados. Sincronize antes de trocar de aparelho. Cada montante é gravado atomicamente, mas a operação completa pode terminar parcialmente.
- O login usa a conta única de demonstração do backend. O perfil é um exemplo; não há gestão de usuários, permissões por função ou recuperação automática de senha.
- O recorte implementado é a Aprovista; não há seleção nem isolamento de dados entre associações.
- O PDF é um relatório gerencial de alimentos e valores, não uma nota fiscal. Não há emissão fiscal, importação automática de novas notas, envio de fotos ou comprovantes assinados.
- O catálogo de alimentos foi definido a partir das notas fornecidas. O catálogo de escolas contém três entradas originais do protótipo e dez EMEFs públicas de Cariacica–ES, confirmadas na lista municipal. A participação dessas escolas na associação ainda precisa de validação operacional. Veja a [lista e fonte](docs/ESCOLAS.md).
- Os valores representam alimentos recebidos e sua destinação; não são receitas, pagamentos, lucro ou saldo bancário. Lotes sem preço são destacados e não integram o subtotal financeiro.
- Os filtros usam a data do montante para a operação e a data de emissão para as notas. A taxa de perdas corresponde a kg perdidos divididos pelos kg recebidos no período, incluindo o estoque que ainda aguarda rateio.
- O status finalizado indica rateio salvo. Não existe confirmação de recebimento pelas escolas nem rastreamento de entregas.
- As quantidades são tratadas em kg e o cálculo usa unidades de 0,1 kg. Não há conversão para litros, unidades ou outras medidas.
- O projeto nativo ainda usa identificadores de exemplo. No Android, a configuração de release usa a assinatura de depuração; o projeto requer preparação para distribuição em lojas.
- Não há registro no repositório que comprove validação operacional com a associação ou resultados de uso em produção.

## Próximos passos propostos

- Substituir a conta única do backend por usuários persistidos, isolamento de associações e regras de acesso; fortalecer o armazenamento local e a recuperação de conflitos.
- Validar o fluxo de pedidos, rateio e confirmação de entregas com a Aprovista.
- Estruturar cadastros e permissões para outras associações citadas no escopo, como Aprucas, Aproder e CAFC.
- Integrar novas notas e comprovantes após definir armazenamento e regras operacionais.
- Validar a execução em Android e iOS e preparar identificadores, assinatura e distribuição.

Esses itens são propostas de evolução, não recursos disponíveis no protótipo.

## Desenvolvimento e versões

O fluxo definido para o projeto usa `develop` como integração e base para `feature/<nome>`. As funcionalidades retornam à `develop` por pull request; a `main` recebe versões após validação. Correções urgentes de versões publicadas usam `hotfix/<nome>` a partir da `main`, com integração também na `develop`. Commits feitos em conjunto registram a autoria adicional com trailers `Co-authored-by`.

A versão segue `MAJOR.MINOR.PATCH+BUILD` no [pubspec.yaml](pubspec.yaml): `MINOR` para novas funcionalidades, `PATCH` para correções e `MAJOR` para mudanças incompatíveis após a versão estável 1.0.0. Durante a fase `0.x`, novas versões menores também podem conter mudanças incompatíveis. O número `BUILD` cresce a cada versão distribuída nas lojas.

Atualize o [CHANGELOG.md](CHANGELOG.md) ao preparar uma versão. Antes de integrar uma release na `main`, valide o aplicativo e execute os testes e a análise estática. As releases usam tags anotadas no formato `vMAJOR.MINOR.PATCH`. A versão atual está registrada no changelog; o sufixo `+11` identifica o build Android 11.
