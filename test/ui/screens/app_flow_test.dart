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

    expect(find.text('Olá, Seu José!'), findsOneWidget);
    await tester.tap(find.text('Entregas'));
    await tester.pumpAndSettle();
    expect(find.text('Nova distribuição'), findsOneWidget);

    await tester.tap(find.text('Nova distribuição'));
    await tester.pumpAndSettle();
    expect(find.text('Quantidade recebida (kg)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
