# Nativa

Protótipo Flutter para a **Aprovista** organizar lotes de alimentos destinados a escolas. O escopo inicial veio de `anotacoes.txt`; as telas e as cores seguem as referências enviadas.

A marca usada nas telas está em `assets/images/nativa_logo.png`. O ícone quadrado em `assets/images/nativa_launcher.png` gera os ícones de Android, iOS e Web com `dart run flutter_launcher_icons`.

## O que já funciona

- Acesso de demonstração com qualquer CPF de 11 dígitos e senha não vazia.
- Painel com calendário, entregas pendentes, total rateado e escolas previstas.
- Cadastro de lote com produto, quantidade recebida, data e pedidos por escola, incluindo colagem de listas para dezenas de escolas.
- Rateio proporcional aos pedidos, limitado à quantidade recebida e ao pedido de cada escola, com precisão de 0,1 kg.
- Lista e detalhe das entregas, com status pendente ou concluído.
- Resumo dos lotes em Documentos e perfil de demonstração.

Os dados ficam apenas na memória durante esta fase. Fechar ou reiniciar o app restaura os exemplos. Login real, cadastro permanente, comprovantes e integração com escolas ainda precisam de backend e regras operacionais validadas com a Aprovista.

O recorte atual é a Aprovista. Aprucas, Aproder e CAFC podem usar o mesmo fluxo depois que cadastros, permissões e regras próprias forem definidos.

## Executar

```sh
flutter pub get
flutter run
```

## Verificar

```sh
dart analyze
flutter test
```

## Fluxo de branches

- `main`: versão pronta para publicação. Recebe mudanças de `develop` somente depois de validação.
- `develop`: integração contínua do aplicativo e base para o trabalho diário.
- `feature/<nome>`: novas funcionalidades criadas a partir de `develop`; retornam para `develop` por pull request.
- `hotfix/<nome>`: correções urgentes de uma versão já publicada, criadas a partir de `main` e integradas também em `develop`.

Antes de levar `develop` para `main`, execute `dart analyze` e `flutter test` e revise as telas afetadas.
