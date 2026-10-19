import 'package:flutter_test/flutter_test.dart';
import 'package:nativa/domain/batch_summary.dart';
import 'package:nativa/domain/models.dart';

void main() {
  test('groups foods in one batch and reports pending status', () {
    final date = DateTime(2026, 10, 15);
    final batches = summarizeBatches([
      Delivery(
        id: 1,
        batchId: 7,
        batchName: 'Dia das Crianças',
        product: 'Aipim',
        availableKg: 100,
        date: date,
        allocations: const [],
      ),
      Delivery(
        id: 2,
        batchId: 7,
        batchName: 'Dia das Crianças',
        product: 'Chuchu',
        availableKg: 30,
        date: date,
        allocations: const [],
        status: DeliveryStatus.completed,
      ),
    ]);

    expect(batches, hasLength(1));
    expect(batches.single.name, 'Dia das Crianças');
    expect(batches.single.receivedKg, 130);
    expect(batches.single.pendingCount, 1);
    expect(batches.single.isCompleted, isFalse);
  });
}
