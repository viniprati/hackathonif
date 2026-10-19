import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nativa/data/delivery_repository.dart';
import 'package:nativa/domain/models.dart';
import 'package:nativa/ui/screens/reports_screen.dart';
import 'package:nativa/ui/theme.dart';
import 'package:nativa/ui/view_models/delivery_view_model.dart';

void main() {
  for (final width in [390.0, 1024.0]) {
    testWidgets(
        'mostra um card por alimento e soma dois recebimentos em $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = DeliveryViewModel(DeliveryRepository());
      addTearDown(model.dispose);
      model.addBatch(
          name: 'Outro montante',
          date: DateTime.now(),
          items: const [
            BatchItem(product: 'Aipim', availableKg: 20, unitPriceCents: 300)
          ]);
      model.saveRequests(
          1, const [SchoolRequest(school: 'IFES', requestedKg: 60)],
          remainderConfirmed: true, lossKg: 10);
      await tester.pumpWidget(MaterialApp(
          theme: nativaTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: Scaffold(body: ReportsScreen(viewModel: model))));
      final foodCard = find.byWidgetPredicate((widget) =>
          widget is ExpansionTile &&
          widget.title is Text &&
          (widget.title as Text).data == 'Aipim');
      final scrollable = find
          .byWidgetPredicate((widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down)
          .first;
      await tester.scrollUntilVisible(foodCard, 400,
          scrollable: scrollable, maxScrolls: 40);
      await tester.pumpAndSettle();
      expect(foodCard, findsOneWidget);
      expect(find.text('Recebido: 120,0 kg\nDistribuído: 60,0 kg'),
          findsOneWidget);
      expect(find.text('Detalhamento dos lotes'), findsNothing);
      await tester
          .tap(find.descendant(of: foodCard, matching: find.text('Aipim')));
      await tester.pumpAndSettle();
      expect(find.text('Sobra aproveitável: 30,0 kg'), findsOneWidget);
      expect(find.text('Perda: 10,0 kg'), findsOneWidget);
      expect(find.text('Aguardando rateio: 20,0 kg'), findsOneWidget);
      expect(
          find.text('Distribuição deste alimento por escola'), findsOneWidget);
      expect(find.text('IFES'), findsWidgets);
      expect(find.text('Ver rateio do lote'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
