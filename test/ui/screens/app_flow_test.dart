import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nativa/main.dart';

void main() {
  testWidgets('mobile flow opens dashboard and new delivery form',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NativaApp());
    await tester.enterText(find.byType(TextFormField).at(0), '12345678901');
    await tester.enterText(find.byType(TextFormField).at(1), 'senha');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('PAINEL DE ATIVIDADES'), findsOneWidget);
    await tester.tap(find.text('Cesta de verduras').first);
    await tester.pumpAndSettle();
    expect(find.text('Rateio por escola'), findsOneWidget);
    Navigator.of(tester.element(find.text('Rateio por escola'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Produtos'));
    await tester.pumpAndSettle();
    expect(find.text('Buscar produto'), findsOneWidget);
    expect(find.text('3 produtos'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ovos');
    await tester.pumpAndSettle();
    expect(find.text('1 produto'), findsOneWidget);
    await tester.tap(find.text('Ovos caipira'));
    await tester.pumpAndSettle();
    expect(find.text('Lotes deste produto'), findsOneWidget);
    await tester.tap(find.textContaining('Lote #2'));
    await tester.pumpAndSettle();
    expect(find.text('Rateio por escola'), findsOneWidget);
    Navigator.of(tester.element(find.text('Rateio por escola'))).pop();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Lotes deste produto'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entregas'));
    await tester.pumpAndSettle();
    expect(find.text('Nova distribuição'), findsOneWidget);

    await tester.tap(find.text('Nova distribuição'));
    await tester.pumpAndSettle();
    expect(find.text('Quantidade recebida (kg)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout opens the product dashboard', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NativaApp());
    await tester.enterText(find.byType(TextFormField).at(0), '12345678901');
    await tester.enterText(find.byType(TextFormField).at(1), 'senha');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Produtos').first);
    await tester.pumpAndSettle();
    expect(find.text('Buscar produto'), findsOneWidget);
    expect(find.text('3 produtos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
