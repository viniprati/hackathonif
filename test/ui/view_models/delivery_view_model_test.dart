import 'package:flutter_test/flutter_test.dart';
import 'package:nativa/data/delivery_repository.dart';
import 'package:nativa/domain/models.dart';
import 'package:nativa/ui/view_models/delivery_view_model.dart';

void main() {
  test('new delivery updates totals and status counts', () {
    final model = DeliveryViewModel(DeliveryRepository());
    final initialPending = model.pendingCount;
    final initialTotal = model.totalDistributedKg;

    model.addDelivery(
      product: 'Batata doce',
      availableKg: 10,
      date: DateTime(2026, 10, 20),
      requests: const [
        SchoolRequest(school: 'IFES', requestedKg: 8),
        SchoolRequest(school: 'Pinto Coelho', requestedKg: 12),
      ],
    );

    expect(model.pendingCount, initialPending + 1);
    expect(model.totalDistributedKg, initialTotal + 10);
    expect(model.deliveries.first.allocations.map((item) => item.allocatedKg), [
      4,
      6,
    ]);

    model.setStatus(model.deliveries.first.id, DeliveryStatus.completed);
    expect(model.pendingCount, initialPending);
    model.dispose();
  });

  test('saving school requests caps allocation and completes one food', () {
    final model = DeliveryViewModel(DeliveryRepository());

    model.saveRequests(1, const [
      SchoolRequest(school: 'IFES', requestedKg: 50),
      SchoolRequest(school: 'Pinto Coelho', requestedKg: 30),
      SchoolRequest(school: 'Darllin', requestedKg: 40),
    ]);

    final aipim = model.deliveries.firstWhere((item) => item.id == 1);
    expect(aipim.status, DeliveryStatus.completed);
    expect(aipim.distributedKg, 100);
    expect(aipim.allocations.map((item) => item.allocatedKg), [
      41.7,
      25,
      33.3,
    ]);
    expect(model.pendingBatchCount, 1);
    model.dispose();
  });
}
