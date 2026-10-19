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
        SchoolRequest(school: 'Escola A', requestedKg: 8),
        SchoolRequest(school: 'Escola B', requestedKg: 12),
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
}
