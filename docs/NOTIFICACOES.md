# Avisos compartilhados e push Android

## O que foi implementado

- Central **Avisos**, disponível após login, e opções no **Perfil → Notificações**.
- **Avisos de montantes** habilita a consulta dos 50 avisos mais recentes; atualização a cada 30 segundos com o app em primeiro plano, ao voltar ao app, após sincronizar ou ao tocar em Atualizar avisos.
- **Receber com o app fechado** inscreve o aparelho Android no Firebase Cloud Messaging, após permissão do sistema e confirmação do backend. Essa opção requer a configuração abaixo e um APK compilado com os dados Firebase.
- Preferências e leitura salvas neste aparelho. Desativar a consulta dentro do app não desativa o push: as opções são independentes.
- Aviso de cadastro após o montante chegar ao servidor; aviso de conclusão quando **todos os alimentos** passam a finalizados. Não é confirmação de entrega física.
- O app continua salvando localmente primeiro: é necessário **Sincronizar dados** no Perfil para os outros aparelhos receberem os avisos. Não é anunciado como compartilhado antes disso.

## Firebase: configuração inicial necessária

1. Crie um projeto no [console Firebase](https://console.firebase.google.com/).
2. Adicione um aplicativo **Android** com o identificador atual `com.example.nativa` (confira [build.gradle.kts](../android/app/build.gradle.kts)). Para atualizar instalações existentes, não altere esse identificador nesta etapa.
3. Baixe o `google-services.json` desse aplicativo e salve em **`android/app/google-services.json`**. Esse arquivo local é ignorado pelo Git. O plugin Google Services só é aplicado quando ele existe, permitindo continuar compilando o MVP sem Firebase. Ele é necessário para o Android iniciar o Firebase também com o processo Dart fechado. O push fica disponível no Android por padrão. Para desabilitar explicitamente, compile com `--dart-define=FIREBASE_ENABLED=false`. O arquivo [firebase-config.example.json](../firebase-config.example.json) continua disponível para builds explícitos.
4. No servidor, habilite a API Firebase Cloud Messaging v1. Em Configurações do projeto → Contas de serviço, obtenha a conta de serviço para o Firebase Admin. Cadastre o JSON completo como variável **`FIREBASE_SERVICE_ACCOUNT_JSON`** no Railway (serviço backend). Nunca coloque essa conta de serviço no APK, no arquivo de configuração do Flutter ou no Git.
5. Reinicie o backend com essa variável. A ausência dela mantém o push desabilitado; a API retorna `PUSH_NOT_CONFIGURED` ao tentar inscrever um aparelho.
6. Compile o Android com:

   ```sh
   flutter build apk --release
   ```

   O `google-services.json` precisa estar na pasta local antes da compilação, mas não deve ser commitado. Sem o arquivo Android, o app continua compilando, mas informa a falta de configuração ao tentar habilitar push. A permissão de notificações Android já está declarada no manifesto.
7. Instale esse APK, faça login e ative **Receber com o app fechado**. Aceite a permissão Android. Todos os aparelhos que fizerem isso receberão os avisos do tópico compartilhado.

Referências: [configurar o cliente Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started), [receber mensagens](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages), [enviar pelo Firebase Admin](https://firebase.google.com/docs/cloud-messaging/send/admin-sdk).

## Backend e persistência

- `GET /v1/notifications?page=1`: avisos compartilhados, com autenticação JWT.
- `GET /v1/notifications/push-status`: informa se o Firebase Admin está configurado no servidor, sem expor credenciais.
- `POST /v1/notifications/push`: `{token, enabled}`, com autenticação, validação e limite de requisições. O token não é registrado nos logs.
- Eventos são embutidos no documento do montante, com escrita atômica junto da alteração e controle de revisão. Repetir uma sincronização já aplicada não cria outro aviso.
- O despachante consulta a fila a cada 15 segundos, usa uma reserva de 120 segundos para evitar envio concorrente por réplicas e registra a aceitação pelo FCM. Falhas mantêm o evento para nova tentativa. Só eventos das últimas 24 horas são candidatos a push; a central mantém até 200 eventos por montante.
- Não há recriação retroativa de avisos de cadastro para montantes antigos que não possuíam eventos. Uma conclusão posterior desses montantes pode gerar aviso.
- O payload da tela bloqueada contém somente uma mensagem genérica. Nome, alimentos e valores ficam na central autenticada.
- A aceitação pelo FCM não comprova recebimento pelo celular. Há possibilidade de repetição se o processo encerrar entre o envio e o registro de aceitação; o identificador e a tag do aviso são estáveis. Não há promessa de entrega exatamente uma vez.

## Limitações e teste manual obrigatório

A configuração Firebase do Android foi recebida e validada localmente: pacote, projeto, ID do aplicativo e remetente correspondem aos recursos gerados pelo Google Services. A conta de serviço foi configurada no `backend/.env` local e validada com FCM em modo dry-run, sem enviar notificações. A configuração no Railway, a publicação do backend e a entrega em aparelho continuam pendentes. Os testes usam gateways simulados para push e MongoDB temporário para persistência; **não comprovam entrega FCM real**.

O projeto ainda autentica uma única conta de demonstração. A central é comum a todas as sessões e o tópico a todos os aparelhos que optarem por receber; não há cadastro de usuários, segmentação por associação ou acompanhamento de leitura por pessoa. A inscrição continua válida com o app fechado. A saída manual tenta removê-la; sem internet, o app orienta a corrigir antes de concluir a saída. A expiração automática da sessão não remove a inscrição, mas o push não contém dados do montante.

Push foi preparado para **Android com Google Play Services**. Na Web e iOS a central funciona, mas não foi implementada a configuração de push dessas plataformas (Web exige service worker/VAPID e iOS exige APNs e capacidades nativas). Se o usuário negar permissão, desativar avisos no sistema ou forçar parada do Android, o recebimento pode ficar impedido até ajustar/reabrir o app.

Após configurar, teste com **dois aparelhos**:

1. Faça login e ative push nos dois. Feche o app no segundo, sem usar Forçar parada.
2. No primeiro, cadastre um montante com dois alimentos e sincronize. Confira um aviso de cadastro no segundo.
3. Finalize só um alimento e sincronize: não deve aparecer conclusão. Finalize o outro, sincronize e confira a conclusão.
4. Abra o aviso e confira a central. Reenvie a mesma sincronização: não deve criar novo evento.
5. Desative push no segundo aparelho e repita com outro montante. Confira que ele não recebe o push e que a central continua disponível se habilitada.
6. Teste permissão negada, falta de internet, retomada do app, troca de token e reinício do backend.

## Verificações desta implementação

- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub`: 100 testes aprovados; 1 integração externa ignorada por não ter URL de teste configurada. Inclui máscara do CPF e envio numérico à API, nove combinações de largura/fonte na barra, persistência da leitura e controle de inscrição com gateway simulado.
- Backend: `npm run typecheck`, `npm run build`, `npm run format:check` e `npm test` aprovados (25 testes).
- `npm run test:integration --prefix backend`: 2 testes aprovados em MongoDB temporário e 1 integração Flutter opcional ignorada. Valida persistência, gravação concorrente dos avisos e reserva de envio. Não altera o Atlas da demonstração.
- `flutter build web --no-wasm-dry-run`: compilação concluída. Há aviso de fonte Cupertino do projeto.
- `flutter build apk --release`: compilação concluída sem configuração Firebase, com push desabilitado. O build emitiu avisos de compatibilidade Kotlin, SDK XML e APIs Java obsoletas.
- `flutter build apk --release`: compilação concluída com o arquivo Android local e Firebase habilitado; recursos de projeto, app e remetente conferidos.
- Firebase Admin/FCM: credencial local aprovada por validação de envio em dry-run, sem entregar mensagem a nenhum aparelho.
- Recebimento real de push, permissão Android e abertura a partir da notificação permanecem pendentes da configuração do Railway e de aparelhos físicos. Compilar o aplicativo sem configuração Firebase não verifica esses comportamentos.
