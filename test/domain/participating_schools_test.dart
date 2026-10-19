import 'package:flutter_test/flutter_test.dart';
import 'package:nativa/data/delivery_repository.dart';
import 'package:nativa/domain/catalog.dart';
import 'package:nativa/domain/models.dart';

void main() {
  test('seleção vale para todos os alimentos e permanece após salvar e reabrir',
      () {
    final repo = DeliveryRepository();
    final schools = ['Darllin', 'IFES'];
    final batchId = repo.addBatch(
        name: 'Montante com duas escolas',
        date: DateTime.now(),
        participatingSchools: schools,
        items: const [
          BatchItem(product: 'Aipim', availableKg: 10),
          BatchItem(product: 'Chuchu', availableKg: 20)
        ]);
    schools.clear();
    final deliveries =
        repo.getAll().where((item) => item.batchId == batchId).toList();
    expect(deliveries, hasLength(2));
    for (final delivery in deliveries) {
      expect(repo.schoolsForDelivery(delivery), ['IFES', 'Darllin']);
      expect(
          delivery.allocations.map((item) => item.school), ['IFES', 'Darllin']);
      expect(
          delivery.allocations.every((item) => item.requestedKg == 0), isTrue);
      expect(() => delivery.participatingSchools!.add('Pinto Coelho'),
          throwsUnsupportedError);
    }
    final delivery = deliveries.first;
    expect(
        () => repo.setRequests(delivery.id,
            const [SchoolRequest(school: 'Pinto Coelho', requestedKg: 0)]),
        throwsArgumentError);
    expect(repo.getAll().firstWhere((item) => item.id == delivery.id),
        same(delivery));
    repo.setRequests(delivery.id,
        [SchoolRequest(school: 'IFES', requestedKg: delivery.availableKg)]);
    var saved = repo.getAll().firstWhere((item) => item.id == delivery.id);
    expect(saved.status, DeliveryStatus.completed);
    expect(saved.allocations.map((item) => item.school), ['IFES', 'Darllin']);
    expect(saved.allocations.last.requestedKg, 0);
    repo.setStatus(saved.id, DeliveryStatus.pending);
    saved = repo.getAll().firstWhere((item) => item.id == delivery.id);
    expect(repo.schoolsForDelivery(saved), ['IFES', 'Darllin']);
  });

  test(
      'rejeita seleção vazia, duplicada ou fora do catálogo sem criar montante',
      () {
    final repo = DeliveryRepository();
    final original = repo.getAll();
    for (final schools in [
      <String>[],
      ['IFES', 'IFES'],
      ['Inventada']
    ]) {
      expect(
          () => repo.addBatch(
              name: 'Inválido',
              date: DateTime.now(),
              participatingSchools: schools,
              items: const [BatchItem(product: 'Aipim', availableKg: 10)]),
          throwsArgumentError);
      expect(repo.getAll(), original);
    }
  });

  test('registros anteriores continuam com as escolas disponíveis', () {
    final repo = DeliveryRepository();
    for (final delivery in repo.getAll()) {
      expect(repo.schoolsForDelivery(delivery), schoolCatalog);
    }
  });
}
