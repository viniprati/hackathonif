import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:nativa/data/batch_api.dart';
import 'package:nativa/data/delivery_repository.dart';
import 'package:nativa/data/manual_sync.dart';
import 'package:nativa/data/sync_store.dart';
import 'package:nativa/domain/models.dart';
import 'package:nativa/domain/sync_batch.dart';
import 'package:nativa/ui/screens/app_shell.dart';
import 'package:nativa/ui/view_models/delivery_view_model.dart';
import 'package:nativa/ui/theme.dart';
import 'package:nativa/ui/sync_card.dart';

import '../../support/fake_batch_api.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'Perfil sincroniza e bloqueia interação enquanto aguarda, fonte $scale',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PackageInfo.setMockInitialValues(
          appName: 'Nativa',
          packageName: 'test.nativa',
          version: '1.0.0',
          buildNumber: '1',
          buildSignature: '');
      final fetch = Completer<List<RemoteBatch>>();
      final api = FakeBatchApi()..onFetch = () => fetch.future;
      final repo = DeliveryRepository(withExamples: false);
      final sync =
          ManualSync(repository: repo, api: api, store: MemorySyncStore());
      final model = DeliveryViewModel(repo, sync: sync);
      addTearDown(model.dispose);
      model.addBatch(
          name: 'Perfil',
          date: DateTime(2026, 10, 20),
          participatingSchools: ['IFES'],
          items: const [BatchItem(product: 'Aipim', availableKg: 100)]);
      await tester.pumpWidget(MaterialApp(
          theme: nativaTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Scaffold(
              body: ProfileScreen(viewModel: model, onSignOut: () {}))));
      final scroll = find
          .byWidgetPredicate((widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down)
          .first;
      await tester.scrollUntilVisible(find.text('Sincronizar dados'), 250,
          scrollable: scroll);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sincronizar dados'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Sincronizando dados'), findsOneWidget);
      expect(sync.busy, isTrue);
      expect(
          () => model.setStatus(
              model.deliveries.single.id, DeliveryStatus.pending),
          throwsStateError);
      await tester.tapAt(const Offset(5, 5));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Sincronizando dados'), findsOneWidget);
      fetch.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('Sincronizando dados'), findsNothing);
      expect(sync.pendingCount, 0);
      expect(sync.lastSyncedAt, isNotNull);
      expect(api.records.length, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Conflito exige escolher antes de substituir edição local',
      (tester) async {
    final api = FakeBatchApi();
    final repo = DeliveryRepository(withExamples: false);
    final sync =
        ManualSync(repository: repo, api: api, store: MemorySyncStore());
    final model = DeliveryViewModel(repo, sync: sync);
    addTearDown(model.dispose);
    model.addBatch(
        name: 'Conflito',
        date: DateTime(2026, 10, 20),
        participatingSchools: ['IFES'],
        items: const [BatchItem(product: 'Aipim', availableKg: 100)]);
    await sync.synchronize();
    final previous = api.records.values.single;
    model.saveRequests(model.deliveries.single.id,
        const [SchoolRequest(school: 'IFES', requestedKg: 50)],
        remainderConfirmed: true, lossKg: 5);
    final remote = previous.snapshot.toJson();
    final item = (remote['items'] as List).single as Map<String, Object?>;
    item['status'] = 'completed';
    item['lossKg'] = 10.0;
    item['requests'] = [
      {'school': 'IFES', 'requestedKg': 70.0}
    ];
    api.records[previous.id] = RemoteBatch(
        id: previous.id, revision: 1, snapshot: BatchSnapshot.fromJson(remote));
    await sync.synchronize();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: SyncCard(sync: sync, onSessionExpired: () {})))));
    await tester.tap(find.text('Revisar versões'));
    await tester.pumpAndSettle();
    expect(find.text('Neste aparelho'), findsOneWidget);
    expect(find.text('No banco'), findsOneWidget);
    await tester.tap(find.text('Manter no aparelho'));
    await tester.pumpAndSettle();
    expect(model.deliveries.single.distributedKg, 50);
    expect(sync.conflicts, hasLength(1));
    expect(
        api.records.values.single.snapshot.items.single.requests.single
            .requestedKg,
        70);
    await tester.tap(find.text('Revisar versões'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar versão do banco'));
    await tester.pumpAndSettle();
    expect(model.deliveries.single.distributedKg, 70);
    expect(sync.conflicts, isEmpty);
    expect(sync.pendingCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Perfil encerra sessão se API devolver 401', (tester) async {
    final api = FakeBatchApi()
      ..readFailure = const SyncFailure('Sessão expirada.', status: 401);
    final repo = DeliveryRepository(withExamples: false);
    final sync =
        ManualSync(repository: repo, api: api, store: MemorySyncStore());
    final model = DeliveryViewModel(repo, sync: sync);
    addTearDown(model.dispose);
    var signedOut = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ProfileScreen(
                viewModel: model,
                onSignOut: () {
                  signedOut = true;
                }))));
    await tester.scrollUntilVisible(find.text('Sincronizar dados'), 250,
        scrollable: find
            .byWidgetPredicate((widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down)
            .first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sincronizar dados'));
    await tester.pumpAndSettle();
    expect(signedOut, isTrue);
    expect(find.text('Sincronizando dados'), findsNothing);
  });
}
