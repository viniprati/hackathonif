import 'package:flutter_test/flutter_test.dart';
import 'package:nativa/data/batch_api.dart';
import 'package:nativa/data/delivery_repository.dart';
import 'package:nativa/data/manual_sync.dart';
import 'package:nativa/data/sync_store.dart';
import 'package:nativa/domain/models.dart';
import 'package:nativa/domain/stock_report.dart';
import 'package:nativa/ui/view_models/delivery_view_model.dart';

import '../support/fake_batch_api.dart';

class BrokenStore extends MemorySyncStore {
  @override
  Future<void> write(String value) async => throw StateError('sem espaço');
}

DeliveryViewModel device(FakeBatchApi api, SyncStore store) {
  final repository = DeliveryRepository(withExamples: false);
  return DeliveryViewModel(repository,
      sync: ManualSync(repository: repository, api: api, store: store));
}

void create(DeliveryViewModel model) => model.addBatch(
        name: 'Compartilhado',
        date: DateTime(2026, 10, 20),
        participatingSchools: [
          'IFES'
        ],
        items: const [
          BatchItem(product: 'Aipim', availableKg: 100, unitPriceCents: 572)
        ]);
void allocate(DeliveryViewModel model, double kg, double loss) =>
    model.saveRequests(model.deliveries.first.id,
        [SchoolRequest(school: 'IFES', requestedKg: kg)],
        remainderConfirmed: true, lossKg: loss);

void main() {
  test('dois aparelhos enviam, baixam e atualizam os relatórios manualmente',
      () async {
    final api = FakeBatchApi();
    final a = device(api, MemorySyncStore());
    final b = device(api, MemorySyncStore());
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await a.initialize();
    await b.initialize();
    expect(a.deliveries, isEmpty);
    expect(api.reads, 0);
    create(a);
    expect(a.sync!.pendingCount, 1);
    await a.sync!.synchronize();
    expect(api.records.length, 1);
    expect(a.sync!.pendingCount, 0);
    expect(b.deliveries, isEmpty);
    await b.sync!.synchronize();
    expect(b.deliveries.single.batchName, 'Compartilhado');
    allocate(a, 60, 10);
    await a.sync!.synchronize();
    expect(b.deliveries.single.status, DeliveryStatus.pending);
    await b.sync!.synchronize();
    expect(b.deliveries.single.distributedKg, 60);
    expect(b.deliveries.single.surplusKg, 30);
    expect(b.deliveries.single.lossKg, 10);
    final report = b.report(ReportPeriod.month, DateTime(2026, 10, 20));
    expect(report.distributedKg, 60);
    expect(report.lossKg, 10);
  });

  test('conflitos preservam edição local e banco até confirmação de usar banco',
      () async {
    final api = FakeBatchApi();
    final a = device(api, MemorySyncStore());
    final cacheB = MemorySyncStore();
    final b = device(api, cacheB);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    create(a);
    await a.sync!.synchronize();
    await b.sync!.synchronize();
    allocate(a, 70, 10);
    allocate(b, 50, 5);
    await a.sync!.synchronize();
    final writes = api.writes;
    await b.sync!.synchronize();
    expect(b.sync!.conflicts.length, 1);
    expect(b.deliveries.single.distributedKg, 50);
    expect(api.writes, writes);
    expect(
        api.records.values.single.snapshot.items.single.requests.single
            .requestedKg,
        70);
    final reopened = device(api, cacheB);
    addTearDown(reopened.dispose);
    await reopened.initialize();
    await reopened.sync!.synchronize();
    expect(reopened.sync!.conflicts.length, 1);
    expect(reopened.deliveries.single.distributedKg, 50);
    await reopened.sync!.useServerVersion(reopened.deliveries.single.batchId);
    expect(reopened.deliveries.single.distributedKg, 70);
    expect(reopened.sync!.pendingCount, 0);
    expect(reopened.sync!.conflicts, isEmpty);
  });

  test('resposta perdida e reinício não duplicam o montante', () async {
    final api = FakeBatchApi()..loseNextSaveResponse = true;
    final cache = MemorySyncStore();
    final a = device(api, cache);
    create(a);
    await a.sync!.synchronize();
    expect(api.records.length, 1);
    expect(a.sync!.pendingCount, 1);
    a.dispose();
    final reopened = device(api, cache);
    addTearDown(reopened.dispose);
    await reopened.initialize();
    await reopened.sync!.synchronize();
    expect(api.records.length, 1);
    expect(api.writes, 1);
    expect(reopened.deliveries.length, 1);
    expect(reopened.sync!.pendingCount, 0);
    expect(cache.value, isNot(contains('accessToken')));
    expect(cache.value, isNot(contains('password')));
  });

  test('rascunhos sobrevivem ao reinício sem consultar a rede', () async {
    final api = FakeBatchApi();
    final cache = MemorySyncStore();
    final a = device(api, cache);
    create(a);
    allocate(a, 60, 10);
    await a.sync!.persist();
    a.dispose();
    final b = device(api, cache);
    addTearDown(b.dispose);
    await b.initialize();
    expect(api.reads, 0);
    expect(b.deliveries.single.distributedKg, 60);
    expect(b.sync!.pendingCount, 1);
    create(b);
    expect(b.deliveries.map((item) => item.id).toSet().length, 2);
  });

  test('falha de armazenamento impede envio antes de salvar chave de criação',
      () async {
    final api = FakeBatchApi();
    final a = device(api, BrokenStore());
    addTearDown(a.dispose);
    create(a);
    await a.sync!.synchronize();
    expect(api.writes, 0);
    expect(api.reads, 0);
    expect(a.deliveries.length, 1);
    expect(a.sync!.pendingCount, 1);
  });

  test('sessão expirada preserva rascunhos e pede novo login', () async {
    final api = FakeBatchApi()
      ..readFailure = const SyncFailure('Entre novamente.', status: 401);
    final a = device(api, MemorySyncStore());
    addTearDown(a.dispose);
    create(a);
    await a.sync!.synchronize();
    expect(a.sync!.sessionExpired, isTrue);
    expect(a.deliveries.length, 1);
    expect(a.sync!.pendingCount, 1);
    expect(api.writes, 0);
  });

  test('cópia local inválida não é apagada ou aplicada parcialmente', () async {
    final cache = MemorySyncStore()..value = '{"schema":99,"batches":[]}';
    final a = device(FakeBatchApi(), cache);
    addTearDown(a.dispose);
    create(a);
    // Aguarda o salvamento solicitado pela edição e prepara uma cópia incompatível.
    await a.sync!.persist();
    cache.value = '{"schema":99,"batches":[]}';
    await expectLater(a.initialize(), throwsFormatException);
    expect(a.deliveries.length, 1);
    expect(cache.value, '{"schema":99,"batches":[]}');
  });
}
