import 'models.dart';

class BatchSummary {
  BatchSummary({
    required this.id,
    required this.name,
    required this.date,
    required Iterable<Delivery> deliveries,
  }) : deliveries = List.unmodifiable(deliveries);

  final int id;
  final String name;
  final DateTime date;
  final List<Delivery> deliveries;

  int get pendingCount => deliveries
      .where((delivery) => delivery.status == DeliveryStatus.pending)
      .length;
  bool get isCompleted => pendingCount == 0;
  double get receivedKg => deliveries.fold<double>(
        0,
        (sum, delivery) => sum + delivery.availableKg,
      );
  int get schoolCount => deliveries
      .expand((delivery) => delivery.allocations)
      .where((allocation) => allocation.allocatedKg > 0)
      .map((allocation) => allocation.school)
      .toSet()
      .length;
}

List<BatchSummary> summarizeBatches(Iterable<Delivery> deliveries) {
  final groups = <int, List<Delivery>>{};
  for (final delivery in deliveries) {
    final id = delivery.batchId == 0 ? -delivery.id : delivery.batchId;
    groups.putIfAbsent(id, () => []).add(delivery);
  }
  return groups.entries.map((entry) {
    final first = entry.value.first;
    return BatchSummary(
      id: entry.key,
      name: first.batchName.isEmpty ? 'Lote #${first.id}' : first.batchName,
      date: first.date,
      deliveries: entry.value,
    );
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}
