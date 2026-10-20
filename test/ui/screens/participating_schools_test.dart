import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nativa/data/delivery_repository.dart';
import 'package:nativa/domain/models.dart';
import 'package:nativa/ui/screens/batch_forms.dart';
import 'package:nativa/ui/screens/batch_details_screen.dart';
import 'package:nativa/ui/view_models/delivery_view_model.dart';
import 'package:nativa/ui/theme.dart';

Future<void> showTarget(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 250,
        scrollable: find
            .byWidgetPredicate((widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down)
            .first);
  }
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pumpAndSettle();
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'cadastro exige seleção e distribuição filtra participantes com fonte $scale',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = DeliveryViewModel(DeliveryRepository());
      addTearDown(model.dispose);
      await tester.pumpWidget(MaterialApp(
          theme: nativaTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Builder(
              builder: (context) => Scaffold(
                  body: Center(
                      child: FilledButton(
                          onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => NewBatchDialog(viewModel: model)),
                          child: const Text('Cadastrar')))))));
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();
      expect(find.text('Nota de referência'), findsNothing);
      expect(find.text('Sem nota vinculada'), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nome do montante (obrigatório)'),
          'Montante selecionado');
      final food = find.byWidgetPredicate((widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Alimento 1 (obrigatório)');
      await showTarget(tester, food);
      await tester.tap(food);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aipim').last);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.ancestor(
              of: find.byWidgetPredicate((w) =>
                  w is TextField &&
                  w.decoration?.labelText?.startsWith('Quantidade ') == true),
              matching: find.byType(TextFormField)),
          '10');
      final price = find.ancestor(
          of: find.byWidgetPredicate((w) =>
              w is TextField &&
              w.decoration?.labelText?.startsWith('Preço de ') == true),
          matching: find.byType(TextFormField));
      await showTarget(tester, price);
      expect(
          tester
              .widget<TextField>(
                  find.descendant(of: price, matching: find.byType(TextField)))
              .readOnly,
          isFalse);
      await tester.enterText(price, '7,25');
      await showTarget(tester, find.text('Salvar montante'));
      await tester.tap(find.text('Salvar montante'));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Selecione pelo menos uma escola que participará deste montante.'),
          findsOneWidget);
      expect(model.batches.any((batch) => batch.name == 'Montante selecionado'),
          isFalse);
      final school = find.byKey(const ValueKey('batch-school-IFES'));
      await showTarget(tester, school);
      await tester.tap(school);
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Selecione pelo menos uma escola que participará deste montante.'),
          findsNothing);
      await showTarget(tester, find.text('Salvar montante'));
      await tester.tap(find.text('Salvar montante'));
      await tester.pumpAndSettle();
      expect(find.byType(NewBatchDialog), findsNothing);
      final delivery = model.deliveries
          .firstWhere((item) => item.batchName == 'Montante selecionado');
      expect(delivery.participatingSchools, ['IFES']);
      expect(delivery.invoiceNumber, isNull);
      expect(delivery.unitPriceCents, 725);
      Navigator.of(tester.element(find.text('Cadastrar'))).push(
          MaterialPageRoute<void>(
              builder: (_) =>
                  AllocationScreen(viewModel: model, deliveryId: delivery.id)));
      await tester.pumpAndSettle();
      await showTarget(tester, find.byKey(const Key('school-quantity-IFES')));
      expect(find.text('IFES'), findsOneWidget);
      expect(find.text('Pinto Coelho'), findsNothing);
      expect(find.text('Darllin'), findsNothing);
      expect(find.byType(TextFormField), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '10');
      await showTarget(tester, find.text('Salvar rateio'));
      await tester.tap(find.text('Salvar rateio'));
      await tester.pumpAndSettle();
      final saved =
          model.deliveries.firstWhere((item) => item.id == delivery.id);
      expect(saved.status, DeliveryStatus.completed);
      expect(saved.participatingSchools, ['IFES']);
      Navigator.of(tester.element(find.text('Cadastrar'))).push(
          MaterialPageRoute<void>(
              builder: (_) =>
                  AllocationScreen(viewModel: model, deliveryId: delivery.id)));
      await tester.pumpAndSettle();
      await showTarget(tester, find.byKey(const Key('school-quantity-IFES')));
      expect(find.byType(TextFormField), findsOneWidget);
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller!
              .text,
          '10,0');
      expect(find.text('Pinto Coelho'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'nova escola de Cariacica pode participar e receber rateio com fonte ampliada',
      (tester) async {
    const school = 'EMEF Arthur da Costa e Silva';
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = DeliveryViewModel(DeliveryRepository());
    addTearDown(model.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: nativaTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Builder(
            builder: (context) => Scaffold(
                body: FilledButton(
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => NewBatchDialog(viewModel: model)),
                    child: const Text('Abrir cadastro'))))));
    await tester.tap(find.text('Abrir cadastro'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNWidgets(13));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do montante (obrigatório)'),
        'Cariacica');
    await showTarget(
        tester, find.byKey(const ValueKey('batch-school-$school')));
    await tester.tap(find.byKey(const ValueKey('batch-school-$school')));
    final food = find.widgetWithText(
        DropdownButtonFormField<String>, 'Alimento 1 (obrigatório)');
    await showTarget(tester, food);
    await tester.tap(food);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aipim').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.ancestor(
            of: find.byWidgetPredicate((w) =>
                w is TextField &&
                w.decoration?.labelText?.startsWith('Quantidade ') == true),
            matching: find.byType(TextFormField)),
        '20');
    await showTarget(tester, find.text('Salvar montante'));
    await tester.tap(find.text('Salvar montante'));
    await tester.pumpAndSettle();
    final delivery =
        model.deliveries.firstWhere((item) => item.batchName == 'Cariacica');
    expect(delivery.participatingSchools, [school]);
    Navigator.of(tester.element(find.text('Abrir cadastro'))).push(
        MaterialPageRoute<void>(
            builder: (_) =>
                AllocationScreen(viewModel: model, deliveryId: delivery.id)));
    await tester.pumpAndSettle();
    await showTarget(tester, find.byKey(const Key('school-quantity-$school')));
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text(school), findsOneWidget);
    expect(find.text('IFES'), findsNothing);
    await tester.enterText(find.byType(TextFormField), '20');
    await showTarget(tester, find.text('Salvar rateio'));
    await tester.tap(find.text('Salvar rateio'));
    await tester.pumpAndSettle();
    final saved = model.deliveries.firstWhere((item) => item.id == delivery.id);
    expect(saved.distributedKg, 20);
    expect(saved.participatingSchools, [school]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card de escolas mostra apenas as participantes do montante',
      (tester) async {
    final model = DeliveryViewModel(DeliveryRepository());
    addTearDown(model.dispose);
    final id = model.addBatch(
        name: 'Só IFES',
        date: DateTime.now(),
        participatingSchools: ['IFES'],
        items: const [BatchItem(product: 'Aipim', availableKg: 10)]);
    await tester.pumpWidget(
        MaterialApp(home: BatchDetailsScreen(viewModel: model, batchId: id)));
    await tester.pumpAndSettle();
    expect(find.text('1 escola participante'), findsOneWidget);
    await showTarget(tester, find.text('ESCOLAS'));
    await tester.tap(find.text('ESCOLAS'));
    await tester.pumpAndSettle();
    expect(find.text('IFES'), findsOneWidget);
    expect(find.text('Pinto Coelho'), findsNothing);
    expect(find.text('Darllin'), findsNothing);
    expect(find.text('Sem pedido neste montante'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
