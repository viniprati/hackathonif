import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nativa/data/auth_repository.dart';
import 'package:nativa/data/sync_store.dart';
import 'package:nativa/main.dart';

import '../../support/test_app.dart';

void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('exige CPF e senha e só entra após autenticação', (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(testApp(tester));
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('Informe 11 dígitos.'), findsOneWidget);
    expect(find.text('Cadastrar montante'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), '00000000000');
    await tester.enterText(find.byType(TextFormField).at(1), 'somente-teste');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Cadastrar montante'), findsOneWidget);
  });

  testWidgets('aguarda servidor e recusa senha incorreta sem abrir início',
      (tester) async {
    phoneSize(tester);
    final response = Completer<http.Response>();
    final repository =
        AuthRepository(client: MockClient((_) => response.future));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
        NativaApp(authRepository: repository, syncStore: MemorySyncStore()));
    await tester.enterText(find.byType(TextFormField).at(0), '00000000000');
    await tester.enterText(find.byType(TextFormField).at(1), 'incorreta');
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('Entrando…'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(find.text('Cadastrar montante'), findsNothing);
    response.complete(http.Response('{}', 401));
    await tester.pumpAndSettle();
    expect(find.text('CPF ou senha inválidos.'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Cadastrar montante'), findsNothing);
  });

  testWidgets('Perfil consulta a versão do pacote e sair encerra a sessão',
      (tester) async {
    phoneSize(tester);
    await tester.pumpWidget(testApp(tester));
    await tester.enterText(find.byType(TextFormField).at(0), '00000000000');
    await tester.enterText(find.byType(TextFormField).at(1), 'somente-teste');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    expect(find.text('Versão 9.8.7 (42)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sair'), 250,
        scrollable: find
            .byWidgetPredicate((widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down)
            .first);
    await tester.ensureVisible(find.text('Sair'));
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Cadastrar montante'), findsNothing);
  });
}
