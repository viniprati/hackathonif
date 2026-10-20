import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/test_app.dart';
import 'package:nativa/data/delivery_repository.dart';
import 'package:nativa/domain/models.dart';
import 'package:nativa/ui/screens/batch_forms.dart';
import 'package:nativa/ui/view_models/delivery_view_model.dart';
import 'package:nativa/ui/theme.dart';

Future<void> signIn(WidgetTester tester) async {
  await tester.pumpWidget(testApp(tester));
  await tester.enterText(find.byType(TextFormField).at(0), '12345678901');
  await tester.enterText(find.byType(TextFormField).at(1), 'senha');
  await tester.ensureVisible(find.text('Entrar'));
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
}

void setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> selectFood(WidgetTester tester, String label, String food) async {
  final field = find.widgetWithText(DropdownButtonFormField<String>, label);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(food).last);
  await tester.tap(find.text(food).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'home has no overview cards; batch cards open information dialogs',
      (tester) async {
    setSize(tester, const Size(390, 844));
    await signIn(tester);
    expect(find.text('ALIMENTOS'), findsNothing);
    expect(find.text('ESCOLAS'), findsNothing);
    expect(find.text('DISTRIBUIÇÃO'), findsNothing);
    await Scrollable.ensureVisible(
        tester.element(find.text('Dia das Crianças')),
        alignment: 0.5);

    await tester.pumpAndSettle();
    await tester.tap(find.text('Dia das Crianças'));
    await tester.pumpAndSettle();
    expect(find.text('ALIMENTOS'), findsOneWidget);
    expect(find.text('ESCOLAS'), findsOneWidget);
    expect(find.text('DISTRIBUIÇÃO'), findsOneWidget);
    await tester.tap(find.text('ALIMENTOS'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Dividir Aipim'));
    await tester.pumpAndSettle();
    final values = [50, 30, 20];
    for (var i = 0; i < values.length; i++) {
      await tester.enterText(find.byType(TextFormField).at(i), '${values[i]}');
    }
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Salvar rateio'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Limite excedido'), findsNothing);
    await tester.tap(find.text('Salvar rateio'));
    await tester.pumpAndSettle();
    expect(find.text('2 alimentos pendentes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('surplus confirmation blocks the screen and records partial loss',
      (tester) async {
    setSize(tester, const Size(390, 844));
    final model = DeliveryViewModel(DeliveryRepository());
    addTearDown(model.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: nativaTheme(),
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => AllocationScreen(
                                  viewModel: model, deliveryId: 1))),
                      child: const Text('Abrir rateio'),
                    )))));
    await tester.tap(find.text('Abrir rateio'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.text('Adicionar escola'), findsNothing);
    expect(find.text('IFES'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('school-quantity-IFES')), '60');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Salvar rateio'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar rateio'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar saldo de alimento'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Confirmar saldo de alimento'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(model.deliveries.first.status, DeliveryStatus.pending);
    await tester.tap(find.text('Salvar rateio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const Key('school-quantity-IFES')))
            .enabled,
        isFalse);
    await tester.tap(find.text('Informar sobra ou perda'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Houve perda').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(
            TextFormField, 'Quantidade perdida (kg, obrigatório)'),
        '10');
    await tester.tap(find.text('Salvar classificação'));
    await tester.pumpAndSettle();
    final saved = model.deliveries.first;
    expect(saved.lossKg, 10);
    expect(saved.surplusKg, 30);
    expect(saved.distributedKg, 60);
    expect(saved.allocations.last.requestedKg, 0);
    expect(saved.status, DeliveryStatus.completed);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets('reports adapt to width ${size.width}', (tester) async {
      setSize(tester, size);
      await signIn(tester);
      await tester.tap(find.text('Relatórios').first);
      await tester.pumpAndSettle();
      expect(find.text('Mensal'), findsOneWidget);
      expect(find.text('Semanal'), findsOneWidget);
      expect(find.textContaining('Taxa de perdas:'), findsOneWidget);
      expect(find.text('Visualizar PDF'), findsOneWidget);
      await tester.tap(find.text('Semanal'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('batch creation uses only catalog selections', (tester) async {
    setSize(tester, const Size(390, 844));
    await signIn(tester);
    await tester.tap(find.text('Cadastrar montante').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do montante (obrigatório)'),
        'Feira de outubro');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Selecionar todas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecionar todas'));
    await tester.pumpAndSettle();
    await selectFood(tester, 'Alimento 1 (obrigatório)', 'Aipim');
    await tester.enterText(
        find.ancestor(
            of: find.byWidgetPredicate((w) =>
                w is TextField &&
                w.decoration?.labelText?.startsWith('Quantidade ') == true),
            matching: find.byType(TextFormField)),
        '40');
    await tester.ensureVisible(find.text('Adicionar alimento'));
    await tester.tap(find.text('Adicionar alimento'));
    await tester.pumpAndSettle();
    await selectFood(tester, 'Alimento 2 (obrigatório)', 'Banana prata');
    await tester.enterText(
        find
            .ancestor(
                of: find.byWidgetPredicate((w) =>
                    w is TextField &&
                    w.decoration?.labelText?.startsWith('Quantidade ') == true),
                matching: find.byType(TextFormField))
            .last,
        '20');
    await tester.ensureVisible(find.text('Salvar montante'));
    await tester.tap(find.text('Salvar montante'));
    await tester.pumpAndSettle();
    expect(find.text('Feira de outubro'), findsOneWidget);
    expect(find.text('5 entregas pendentes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
