import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/test_app.dart';
import 'package:nativa/ui/text_size_controls.dart';

void main() {
  test('ampliação preserva a curva de tamanho do sistema', () {
    const scaler = ReaderTextScaler(TextScaler.linear(1.5), 2);
    expect(scaler.scale(16), 48);
  });

  testWidgets('restaurar mantém o tamanho escolhido no aparelho',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(testApp(tester));
    final field = find.byType(TextFormField).first;
    expect(MediaQuery.textScalerOf(tester.element(field)).scale(16), 24);
    await tester.tap(find.byTooltip('Aumentar letras'));
    await tester.pumpAndSettle();
    expect(MediaQuery.textScalerOf(tester.element(field)).scale(16),
        closeTo(28.8, 0.001));
    await tester
        .tap(find.byTooltip('Restaurar tamanho das letras do aparelho'));
    await tester.pumpAndSettle();
    expect(MediaQuery.textScalerOf(tester.element(field)).scale(16), 24);
    expect(
        tester
            .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.text_decrease))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1024.0]) {
    testWidgets('letras ampliadas nas telas e diálogos em $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(testApp(tester));
      await tester.enterText(find.byType(TextFormField).at(0), '12345678901');
      await tester.enterText(find.byType(TextFormField).at(1), 'senha');
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byTooltip('Aumentar letras'));
        await tester.pumpAndSettle();
      }
      expect(find.text('200%'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.text_increase),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller
            ?.text,
        '12345678901',
      );
      await tester.ensureVisible(find.text('Entrar'));
      await tester.ensureVisible(find.text('Entrar'));
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.text('Olá, Seu José!')),
        ).scale(16),
        32,
      );
      for (final tab in ['Montantes', 'Produtos', 'Relatórios', 'Perfil']) {
        if (width < 700) {
          await tester.tap(find.byTooltip('Navegar entre páginas'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
        if (tab == 'Produtos' || tab == 'Relatórios') {
          for (var scroll = 0; scroll < 4; scroll++) {
            await tester.drag(
              find
                  .byWidgetPredicate(
                    (widget) =>
                        widget is Scrollable &&
                        widget.axisDirection == AxisDirection.down,
                  )
                  .first,
              const Offset(0, -350),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$tab ao rolar');
          }
        }
      }
      if (width < 700) {
        await tester.tap(find.byTooltip('Navegar entre páginas'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Montantes').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Dia das Crianças'),
        250,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.text('Dia das Crianças'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ALIMENTOS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALIMENTOS'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final dialog = find.byType(AlertDialog);
      expect(MediaQuery.textScalerOf(tester.element(dialog)).scale(16), 32);
      await tester.tap(find.byTooltip('Diminuir letras'));
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);
      expect(MediaQuery.textScalerOf(tester.element(dialog)).scale(16),
          closeTo(28.8, 0.001));
      await tester.tap(
        find.byTooltip('Restaurar tamanho das letras do aparelho'),
      );
      await tester.pumpAndSettle();
      expect(MediaQuery.textScalerOf(tester.element(dialog)).scale(16), 16);
      expect(tester.takeException(), isNull);
    });
  }
}
