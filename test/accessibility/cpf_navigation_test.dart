import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nativa/ui/formatters/cpf_formatter.dart';
import 'package:nativa/ui/screens/app_shell.dart';
import 'package:nativa/ui/theme.dart';

void main() {
  test('CPF: pontuação progressiva, colagem, limite e cursor no meio', () {
    const formatter = CpfFormatter();
    TextEditingValue value(String v, [int? offset]) => TextEditingValue(
        text: v,
        selection: TextSelection.collapsed(offset: offset ?? v.length));
    const expected = [
      '',
      '1',
      '12',
      '123',
      '123.4',
      '123.45',
      '123.456',
      '123.456.7',
      '123.456.78',
      '123.456.789',
      '123.456.789-0',
      '123.456.789-00'
    ];
    const full = '12345678900';
    for (var i = 0; i <= 11; i++) {
      final result = formatter.formatEditUpdate(
          TextEditingValue.empty, value(full.substring(0, i)));
      expect(result.text, expected[i]);
      expect(result.selection.extentOffset, result.text.length);
    }
    expect(
        formatter
            .formatEditUpdate(
                TextEditingValue.empty, value('123.456.789-001234'))
            .text,
        expected.last);
    final edited = formatter.formatEditUpdate(
        value(expected.last), value('123.956.789-00', 5));
    expect(edited.text, '123.956.789-00');
    expect(edited.selection.extentOffset, 5);
    expect(cpfDigits(edited.text), '12395678900');
  });
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('barra sem quebra nos rótulos: $width, fonte $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var selected = -1;
        await tester.pumpWidget(MaterialApp(
            theme: nativaTheme(highContrast: true),
            home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                    bottomNavigationBar: AccessibleBottomNavigation(
                        selectedIndex: 0,
                        onSelected: (i) => selected = i,
                        destinations: const [
                      NavigationDestination(
                          icon: Icon(Icons.home), label: 'Início'),
                      NavigationDestination(
                          icon: Icon(Icons.local_shipping), label: 'Montantes'),
                      NavigationDestination(
                          icon: Icon(Icons.inventory_2), label: 'Produtos'),
                      NavigationDestination(
                          icon: Icon(Icons.description), label: 'Relatórios'),
                      NavigationDestination(
                          icon: Icon(Icons.person), label: 'Perfil'),
                    ])))));
        for (final text in [
          'Início',
          'Montantes',
          'Produtos',
          'Relatórios',
          'Perfil'
        ]) {
          final label = find.text(text);
          await tester.ensureVisible(label);
          await tester.pumpAndSettle();
          expect(tester.widget<Text>(label).softWrap, isFalse);
          expect(
              tester
                  .getSize(find.ancestor(
                      of: label, matching: find.byType(TextButton)))
                  .height,
              greaterThanOrEqualTo(48));
        }
        await tester.tap(find.text('Perfil'));
        expect(selected, 4);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
