import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nativa/data/delivery_repository.dart';
import 'package:nativa/domain/models.dart';
import 'package:nativa/domain/stock_report.dart';
import 'package:nativa/ui/report_charts.dart';
import 'package:nativa/ui/screens/batch_forms.dart';
import 'package:nativa/ui/screens/products_screen.dart';
import 'package:nativa/ui/theme.dart';
import 'package:nativa/ui/view_models/delivery_view_model.dart';

void main() {
  test('bloqueia soma excedida sem alterar os dados e aceita o limite exato',
      () {
    final repo = DeliveryRepository();
    final original = repo.getAll().firstWhere((item) => item.id == 1);
    expect(
        () => repo.setRequests(1, const [
              SchoolRequest(school: 'IFES', requestedKg: 60),
              SchoolRequest(school: 'Darllin', requestedKg: 40.1),
            ]),
        throwsArgumentError);
    expect(repo.getAll().firstWhere((item) => item.id == 1), same(original));
    expect(
        () => repo.add(
            product: 'Aipim',
            availableKg: 10,
            date: DateTime.now(),
            requests: const [SchoolRequest(school: 'IFES', requestedKg: 10.1)]),
        throwsArgumentError);
    repo.setRequests(
        1, const [SchoolRequest(school: 'IFES', requestedKg: 100)]);
    expect(repo.getAll().firstWhere((item) => item.id == 1).distributedKg, 100);
  });

  testWidgets('pedidos excedidos mostram erro e não podem ser salvos',
      (tester) async {
    final model = DeliveryViewModel(DeliveryRepository());
    addTearDown(model.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: nativaTheme(),
        home: AllocationScreen(viewModel: model, deliveryId: 1)));
    await tester.enterText(find.byType(TextFormField).at(0), '60');
    await tester.enterText(find.byType(TextFormField).at(1), '40,1');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Salvar rateio'), 250,
        scrollable: find
            .byWidgetPredicate((widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down)
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar rateio'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Limite excedido em 0,1 kg'), findsOneWidget);
    expect(model.deliveries.firstWhere((item) => item.id == 1).status,
        DeliveryStatus.pending);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(1), '40');
    await tester.pumpAndSettle();
    expect(find.textContaining('Limite excedido'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('os três indicadores de produtos abrem os detalhes corretos',
      (tester) async {
    final model = DeliveryViewModel(DeliveryRepository());
    addTearDown(model.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: nativaTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(body: ProductsScreen(viewModel: model))));
    for (final item in [
      ('Produtos', 'Produtos cadastrados'),
      ('Recebido', 'Recebimentos por produto'),
      ('Rateado', 'Rateios por escola')
    ]) {
      final label = find.byKey(ValueKey('product-metric-${item.$1}'));
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(find.text(item.$2), findsOneWidget);
      if (item.$1 == 'Rateado') {
        expect(find.text('IFES'), findsOneWidget);
        expect(find.text('60,0 kg'), findsOneWidget);
      } else {
        expect(find.text('Aipim'), findsWidgets);
      }
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
    }
    await tester
        .ensureVisible(find.byKey(const ValueKey('product-metric-Produtos')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('product-metric-Produtos')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Aipim')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Lotes deste produto'), 250,
        scrollable: find
            .byWidgetPredicate((widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down)
            .first);
    await tester.pumpAndSettle();
    expect(find.text('Lotes deste produto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1024.0]) {
    testWidgets('gráficos acessíveis reconciliam os kg em $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = DeliveryRepository();
      repo.setRequests(
          1, const [SchoolRequest(school: 'IFES', requestedKg: 60)],
          remainderConfirmed: true, lossKg: 10);
      repo.addBatch(
          name: 'Outro lote',
          date: DateTime.now(),
          items: const [BatchItem(product: 'Aipim', availableKg: 20)]);
      final report = StockReport(
          period: ReportPeriod.month,
          reference: DateTime.now(),
          deliveries: repo.getAll(),
          invoices: const []);
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: ReportCharts(report: report))))));
      await tester.pumpAndSettle();
      expect(find.text('Total recebido: 180,0 kg'), findsOneWidget);
      expect(find.text('Distribuído: 60,0 kg (33,3%)'), findsOneWidget);
      expect(find.text('Perda: 10,0 kg (5,6%)'), findsOneWidget);
      expect(
          find.bySemanticsLabel(
              'Aipim: 120,0 kg recebidos, 60,0 kg distribuídos'),
          findsOneWidget);
      await tester.ensureVisible(find.text('IFES • 60,0 kg'));
      await tester.pumpAndSettle();
      expect(
          find.bySemanticsLabel('IFES: 60,0 kg distribuídos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('período vazio não produz gráficos inválidos', (tester) async {
    final report = StockReport(
        period: ReportPeriod.month,
        reference: DateTime(2020),
        deliveries: const [],
        invoices: const []);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(child: ReportCharts(report: report)))));
    expect(find.text('Sem alimentos recebidos neste período.'), findsOneWidget);
    expect(find.text('Sem distribuição salva neste período.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
