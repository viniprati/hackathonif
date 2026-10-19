import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nativa/main.dart';

Future<void> signIn(WidgetTester tester) async {
  await tester.pumpWidget(const NativaApp());
  await tester.enterText(find.byType(TextFormField).at(0), '12345678901');
  await tester.enterText(find.byType(TextFormField).at(1), 'senha');
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mobile flow divides a batch product among schools',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await signIn(tester);
    expect(find.text('ASSOCIAÇÃO APROVISTA'), findsOneWidget);
    expect(find.text('3 entregas pendentes'), findsOneWidget);

    await tester.ensureVisible(find.text('Dia das Crianças'));
    await tester.tap(find.text('Dia das Crianças'));
    await tester.pumpAndSettle();
    expect(
        find.text('Selecione o alimento que deseja separar'), findsOneWidget);
    await tester.tap(find.byKey(const Key('batch-product-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dividir entre escolas'));
    await tester.pumpAndSettle();
    expect(find.text('Pedidos das escolas'), findsOneWidget);

    final quantities = find.widgetWithText(TextFormField, 'Pedido (kg)');
    await tester.enterText(quantities.at(0), '50');
    await tester.enterText(quantities.at(1), '30');
    await tester.enterText(quantities.at(2), '40');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salvar rateio'));
    expect(find.textContaining('Faltam 20,0 kg'), findsOneWidget);
    await tester.tap(find.text('Salvar rateio'));
    await tester.pumpAndSettle();
    expect(find.text('100,0 kg • Finalizado'), findsOneWidget);
    Navigator.of(tester
            .element(find.text('Selecione o alimento que deseja separar')))
        .pop();
    await tester.pumpAndSettle();
    expect(find.text('2 alimentos pendentes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout opens batches and products', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await signIn(tester);
    await tester.tap(find.text('Montantes').first);
    await tester.pumpAndSettle();
    expect(
        find.text('Selecione o montante que deseja dividir.'), findsOneWidget);
    expect(find.text('2 montantes'), findsOneWidget);

    await tester.tap(find.text('Finalizados'));
    await tester.pumpAndSettle();
    expect(find.text('1 montante'), findsOneWidget);
    await tester.tap(find.text('Todos'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar montantes'),
      'aipim',
    );
    await tester.pumpAndSettle();
    expect(find.text('1 montante'), findsOneWidget);

    await tester.tap(find.text('Produtos').first);
    await tester.pumpAndSettle();
    expect(find.text('Buscar produto'), findsOneWidget);
    expect(find.text('5 produtos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registers a batch with multiple foods', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await signIn(tester);
    await tester.tap(find.text('Cadastrar montante').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do montante'),
        'Feira de outubro');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Alimento 1'), 'Abóbora');
    await tester.enterText(find.widgetWithText(TextFormField, 'Kg'), '40');
    await tester.tap(find.text('Adicionar alimento'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Alimento 2'), 'Cenoura');
    await tester.enterText(find.widgetWithText(TextFormField, 'Kg').last, '20');
    await tester.ensureVisible(find.text('Salvar montante'));
    await tester.tap(find.text('Salvar montante'));
    await tester.pumpAndSettle();
    expect(find.text('Feira de outubro'), findsOneWidget);
    expect(find.text('5 entregas pendentes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
