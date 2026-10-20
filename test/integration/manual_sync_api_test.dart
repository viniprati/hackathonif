import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nativa/data/auth_repository.dart';
import 'package:nativa/data/batch_api.dart';
import 'package:nativa/data/delivery_repository.dart';
import 'package:nativa/data/manual_sync.dart';
import 'package:nativa/data/sync_store.dart';
import 'package:nativa/domain/models.dart';
import 'package:nativa/domain/stock_report.dart';
import 'package:nativa/ui/view_models/delivery_view_model.dart';

class LoseResponseClient extends http.BaseClient {
  final http.Client inner = http.Client();
  bool loseNextPut = true;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    if (request.method == 'PUT' && loseNextPut) {
      loseNextPut = false;
      await response.stream.drain<void>();
      throw http.ClientException('Resposta de teste perdida após gravar');
    }
    return response;
  }

  @override
  void close() => inner.close();
}

void main() {
  final target = Platform.environment['NATIVA_SYNC_TEST_URL'];
  test(
      'Flutter e API MongoDB: dois aparelhos, conflitos, reinício e reenvio após perda de resposta',
      () async {
    final uri = Uri.parse(target!);
    expect(uri.host, '127.0.0.1',
        reason: 'Este teste só pode usar a API isolada local.');
    final auths = <AuthRepository>[];
    final devices = <DeliveryViewModel>[];
    addTearDown(() {
      for (final device in devices) {
        device.dispose();
      }
      for (final auth in auths) {
        auth.dispose();
      }
    });
    Future<DeliveryViewModel> device(SyncStore store,
        {http.Client? client}) async {
      final auth = AuthRepository(baseUrl: target, client: client);
      auths.add(auth);
      await auth.signIn(Platform.environment['NATIVA_SYNC_TEST_CPF']!,
          Platform.environment['NATIVA_SYNC_TEST_PASSWORD']!);
      final repository = DeliveryRepository(withExamples: false);
      final model = DeliveryViewModel(repository,
          sync: ManualSync(
              repository: repository, api: BatchApi(auth), store: store));
      devices.add(model);
      await model.initialize();
      return model;
    }

    void create(DeliveryViewModel model, String name, double received) =>
        model.addBatch(
            name: name,
            date: DateTime(2026, 10, 20),
            participatingSchools: [
              'EMEF Arthur da Costa e Silva'
            ],
            items: [
              BatchItem(
                  product: 'Aipim', availableKg: received, unitPriceCents: 572)
            ]);
    void allocate(DeliveryViewModel model, double kg, double loss) =>
        model.saveRequests(
            model.deliveries.single.id,
            [
              SchoolRequest(
                  school: 'EMEF Arthur da Costa e Silva', requestedKg: kg)
            ],
            remainderConfirmed: true,
            lossKg: loss);
    Future<void> synchronize(DeliveryViewModel model) async {
      await model.sync!.synchronize();
      expect(model.sync!.message, 'Dados enviados e atualizados com sucesso.');
    }

    final a = await device(MemorySyncStore());
    final cacheB = MemorySyncStore();
    final b = await device(cacheB);
    create(a, 'Compartilhado isolado', 100);
    await synchronize(a);
    await synchronize(b);
    expect(b.deliveries.single.availableKg, 100);
    allocate(a, 60, 10);
    await synchronize(a);
    await synchronize(b);
    expect(b.deliveries.single.distributedKg, 60);
    expect(b.deliveries.single.surplusKg, 30);
    expect(b.deliveries.single.lossKg, 10);
    expect(
        b.report(ReportPeriod.month, DateTime(2026, 10, 20)).distributedKg, 60);
    allocate(a, 70, 10);
    allocate(b, 50, 5);
    await synchronize(a);
    await b.sync!.synchronize();
    expect(b.sync!.conflicts.length, 1);
    expect(b.deliveries.single.distributedKg, 50);
    final reopened = await device(cacheB);
    await reopened.sync!.synchronize();
    expect(reopened.sync!.conflicts.length, 1);
    await reopened.sync!.useServerVersion(reopened.deliveries.single.batchId);
    expect(reopened.deliveries.single.distributedKg, 70);
    expect(reopened.sync!.pendingCount, 0);

    final uncertainCache = MemorySyncStore();
    final uncertain =
        await device(uncertainCache, client: LoseResponseClient());
    create(uncertain, 'Reenvio isolado', 25);
    await uncertain.sync!.synchronize();
    expect(uncertain.sync!.pendingCount, 1);
    final restored = await device(uncertainCache);
    await synchronize(restored);
    expect(restored.batches.length, 2);
    expect(
        restored.batches
            .where((batch) => batch.name == 'Reenvio isolado')
            .length,
        1);
    expect(restored.sync!.pendingCount, 0);
    expect(restored.deliveries.map((item) => item.id).toSet().length, 2);
    expect(
        restored
            .report(ReportPeriod.month, DateTime(2026, 10, 20))
            .distributedKg,
        70);
  },
      timeout: const Timeout(Duration(minutes: 2)),
      skip: target == null
          ? 'Execute o teste de integração backend com FLUTTER_BIN configurado.'
          : false);
}
