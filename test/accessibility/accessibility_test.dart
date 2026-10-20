import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nativa/data/delivery_repository.dart';
import 'package:nativa/data/sync_store.dart';
import 'package:nativa/main.dart';
import 'package:nativa/ui/screens/batch_forms.dart';
import 'package:nativa/ui/screens/batch_screen.dart';
import 'package:nativa/ui/screens/home_screen.dart';
import 'package:nativa/ui/screens/delivery_screen.dart';
import 'package:nativa/ui/theme.dart';
import 'package:nativa/ui/view_models/delivery_view_model.dart';
import '../support/test_app.dart';

void size(WidgetTester tester, {double width = 390}) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> visible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 250,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Finder input(String prefix) => find.ancestor(
    of: find.byWidgetPredicate((w) =>
        w is TextField &&
        (w.decoration?.labelText?.startsWith(prefix) ?? false)),
    matching: find.byType(TextFormField));
Future<DeliveryViewModel> form(WidgetTester tester,
    {double scale = 1, bool keyboard = false}) async {
  size(tester);
  if (keyboard) {
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
  }
  final model = DeliveryViewModel(DeliveryRepository());
  addTearDown(model.dispose);
  await tester.pumpWidget(MaterialApp(
      theme: nativaTheme(highContrast: true),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
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
  return model;
}

void accessibleTest(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await body(tester);
    } finally {
      handle.dispose();
    }
  });
}

void main() {
  test('paleta: texto >= 4,5 e contornos >= 3, nos dois temas', () {
    for (final enabled in [false, true]) {
      final theme = nativaTheme(highContrast: enabled),
          scheme = theme.colorScheme;
      for (final pair in [
        (scheme.onSurface, scheme.surface),
        (scheme.onSurfaceVariant, Colors.white),
        (scheme.onPrimary, scheme.primary),
        (scheme.onPrimaryContainer, scheme.primaryContainer),
        (scheme.onSecondaryContainer, scheme.secondaryContainer),
        (scheme.error, Colors.white),
        (NativaColors.gray, NativaColors.lightGreen),
        (NativaColors.earth, NativaColors.cream),
        (NativaColors.darkGreen, NativaColors.lightGreen),
        (Colors.black, NativaColors.yellow)
      ]) {
        expect(contrastRatio(pair.$1, pair.$2), greaterThanOrEqualTo(4.5),
            reason: '$enabled $pair');
      }
      expect(
          contrastRatio(scheme.outline, Colors.white), greaterThanOrEqualTo(3));
      expect(
          contrastRatio(scheme.error, Colors.white), greaterThanOrEqualTo(3));
      for (final states in [
        <WidgetState>{},
        {WidgetState.disabled}
      ]) {
        final style = theme.filledButtonTheme.style!;
        expect(
            contrastRatio(style.foregroundColor!.resolve(states)!,
                style.backgroundColor!.resolve(states)!),
            greaterThanOrEqualTo(4.5));
      }
    }
  });

  accessibleTest(
      'alto contraste no login preserva campos e fonte ampliada; preferência persiste',
      (tester) async {
    size(tester);
    final store = MemorySyncStore();
    await tester.pumpWidget(NativaApp(
        authRepository: testAuthRepository(),
        syncStore: MemorySyncStore(),
        accessibilityStore: store));
    await tester.pumpAndSettle();
    await tester.enterText(input('CPF'), '12345678900');
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip('Aumentar letras'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('Acessibilidade'));
    await tester.pumpAndSettle();
    await visible(tester, find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(store.value, contains('true'));
    expect(
        Theme.of(tester.element(find.byType(SwitchListTile)))
            .colorScheme
            .primary,
        Colors.black);
    await visible(tester, find.text('Fechar'));
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(input('CPF')).controller!.text,
        '12345678900');
    expect(MediaQuery.textScalerOf(tester.element(input('CPF'))).scale(16), 32);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(NativaApp(
        authRepository: testAuthRepository(),
        syncStore: MemorySyncStore(),
        accessibilityStore: store));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(input('CPF'))).colorScheme.primary,
        Colors.black);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final scale in [1.0, 2.0]) {
    accessibleTest(
        'login: rótulos, contraste, toque e primeiro erro com fonte $scale',
        (tester) async {
      size(tester);
      await tester.pumpWidget(NativaApp(
          authRepository: testAuthRepository(),
          syncStore: MemorySyncStore(),
          accessibilityStore: MemorySyncStore()
            ..value = '{"highContrast":true}'));
      await tester.pumpAndSettle();
      if (scale == 2) {
        for (var i = 0; i < 5; i++) {
          await tester.tap(find.byTooltip('Aumentar letras'));
          await tester.pumpAndSettle();
        }
      }
      await visible(tester, find.text('Entrar'));
      await tester.ensureVisible(find.text('Entrar'));
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      final editable = tester.widget<EditableText>(find.descendant(
          of: input('CPF'), matching: find.byType(EditableText)));
      expect(editable.focusNode.hasFocus, isTrue);
      expect(find.text('Informe 11 dígitos.'), findsOneWidget);
      expect(tester.getSemantics(input('CPF')).getSemanticsData().label,
          contains('CPF'));
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  accessibleTest(
      'rascunho: desfazer restaura alimento, quantidade e preço sem prazo',
      (tester) async {
    final model = await form(tester, scale: 2, keyboard: true);
    final before = model.batches.length;
    await visible(tester, find.byType(DropdownButtonFormField<String>).first);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aipim').last);
    await tester.pumpAndSettle();
    await tester.enterText(input('Quantidade'), '10,5');
    await tester.enterText(input('Preço de'), '7,25');
    await visible(tester, find.text('Adicionar alimento'));
    await tester.tap(find.text('Adicionar alimento'));
    await tester.pumpAndSettle();
    await visible(tester, find.text('Remover Aipim'));
    await tester.tap(find.text('Remover Aipim'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Desfazer remoção de Aipim'), findsOneWidget);
    await visible(tester, find.text('Desfazer remoção de Aipim'));
    await tester.tap(find.text('Desfazer remoção de Aipim'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(input('Quantidade Aipim'))
            .controller!
            .text,
        '10,5');
    expect(
        tester.widget<TextFormField>(input('Preço de Aipim')).controller!.text,
        '7,25');
    expect(model.batches.length, before);
    expect(tester.takeException(), isNull);
  });

  accessibleTest(
      'cancelar cadastro preenchido pede confirmação e preserva ao cancelar descarte',
      (tester) async {
    final model = await form(tester);
    final before = model.batches.length;
    await tester.enterText(input('Nome do montante'), 'Rascunho de outubro');
    await visible(tester, find.text('Cancelar'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Rascunho de outubro ainda não foi salvo'),
        findsOneWidget);
    await tester.tap(find.text('Cancelar').last);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(input('Nome do montante'))
            .controller!
            .text,
        'Rascunho de outubro');
    await visible(tester, find.text('Cancelar'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar cadastro'));
    await tester.pumpAndSettle();
    expect(find.byType(NewBatchDialog), findsNothing);
    expect(model.batches.length, before);
  });

  accessibleTest('limpar escolas permite desfazer a seleção original sem prazo',
      (tester) async {
    await form(tester);
    final first = find.byType(CheckboxListTile).first;
    await visible(tester, first);
    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(first).value, isTrue);
    await visible(tester, find.text('Limpar seleção'));
    await tester.tap(find.text('Limpar seleção'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(first).value, isFalse);
    await tester.pump(const Duration(minutes: 1));
    await visible(tester, find.text('Desfazer limpeza das escolas'));
    await tester.tap(find.text('Desfazer limpeza das escolas'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(first).value, isTrue);
  });

  accessibleTest('detalhe do rateio permanece legível com fonte de 200%',
      (tester) async {
    size(tester, width: 320);
    final model = DeliveryViewModel(DeliveryRepository());
    addTearDown(model.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: nativaTheme(highContrast: true),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!),
      home: DeliveryDetails(
          viewModel: model, deliveryId: model.deliveries.first.id),
    ));
    await visible(tester, find.text('Editar rateio'));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    expect(tester.takeException(), isNull);
  });

  accessibleTest(
      'substituir rateio finalizado exige confirmação e cancelar preserva o original',
      (tester) async {
    size(tester);
    final model = DeliveryViewModel(DeliveryRepository());
    addTearDown(model.dispose);
    final original = model.deliveries.firstWhere((d) => d.id == 4);
    await tester.pumpWidget(MaterialApp(
        theme: nativaTheme(highContrast: true),
        home: AllocationScreen(viewModel: model, deliveryId: original.id)));
    await visible(tester, find.text('Salvar rateio'));
    await tester.tap(find.text('Salvar rateio'));
    await tester.pumpAndSettle();
    expect(find.text('Substituir rateio de Banana prata?'), findsOneWidget);
    expect(find.textContaining('Não há histórico'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(model.deliveries.firstWhere((d) => d.id == 4), same(original));
    expect(find.byType(AllocationScreen), findsOneWidget);
    expect(find.textContaining('Rateio salvo neste aparelho'), findsNothing);
  });

  accessibleTest(
      'calendário expõe data e seleção, com alvos de 48 px e foco por teclado',
      (tester) async {
    size(tester, width: 320);
    final model = DeliveryViewModel(DeliveryRepository());
    addTearDown(model.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: nativaTheme(highContrast: true),
        home:
            Scaffold(body: HomeScreen(viewModel: model, openBatches: () {}))));
    final days = find.byWidgetPredicate((w) =>
        w is Semantics &&
        w.properties.label?.contains(' montantes') == true &&
        w.properties.button == true);
    expect(days, findsWidgets);
    final day = days.first;
    final target = find.descendant(of: day, matching: find.byType(TextButton));
    expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(tester.widget<Semantics>(days.first).properties.selected, isTrue);
    expect(tester.getSemantics(days.first).getSemanticsData().label,
        contains('${model.selectedMonth.year}'));
  });

  accessibleTest('card de montante é um único botão com nome e estado',
      (tester) async {
    final model = DeliveryViewModel(DeliveryRepository());
    addTearDown(model.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: nativaTheme(highContrast: true),
        home: Scaffold(
            body: BatchCard(batch: model.batches.first, onTap: () {}))));
    final node = tester.getSemantics(find.byType(AccessibleInkWell));
    expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(node.getSemanticsData().label, contains(model.batches.first.name));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  });
}
