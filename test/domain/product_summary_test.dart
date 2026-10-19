import 'package:flutter_test/flutter_test.dart';
import 'package:nativa/domain/models.dart';
import 'package:nativa/domain/product_summary.dart';

void main() {
  test('groups product lots and totals received and allocated quantities', () {
    final deliveries = [
      Delivery(
        id: 1,
        product: ' Banana  Prata ',
        availableKg: 100,
        date: DateTime(2026, 10, 19),
        allocations: const [
          Allocation(school: 'Escola A', requestedKg: 60, allocatedKg: 50),
          Allocation(school: 'Escola B', requestedKg: 40, allocatedKg: 30),
        ],
      ),
      Delivery(
        id: 2,
        product: 'banana prata',
        availableKg: 50,
        date: DateTime(2026, 10, 20),
        allocations: const [
          Allocation(school: 'Escola A', requestedKg: 20, allocatedKg: 20),
        ],
        status: DeliveryStatus.completed,
      ),
      Delivery(
        id: 3,
        product: 'Tomate',
        availableKg: 25,
        date: DateTime(2026, 10, 21),
        allocations: const [],
      ),
    ];

    final products = summarizeProducts(deliveries);

    expect(products.map((product) => product.name), [
      'Banana Prata',
      'Tomate',
    ]);
    final banana = products.first;
    expect(banana.lotCount, 2);
    expect(banana.pendingCount, 1);
    expect(banana.completedCount, 1);
    expect(banana.schoolCount, 2);
    expect(banana.receivedKg, 150);
    expect(banana.distributedKg, 100);
    expect(banana.unallocatedKg, 50);
  });
}
