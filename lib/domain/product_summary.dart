import 'models.dart';

class ProductSummary {
  ProductSummary({required this.name, required Iterable<Delivery> deliveries})
      : deliveries = List.unmodifiable(deliveries);

  final String name;
  final List<Delivery> deliveries;

  String get key => normalizedProductName(name);
  int get lotCount => deliveries.length;
  int get pendingCount => deliveries
      .where((delivery) => delivery.status == DeliveryStatus.pending)
      .length;
  int get completedCount => lotCount - pendingCount;
  double get receivedKg => deliveries.fold<double>(
        0,
        (total, delivery) => total + delivery.availableKg,
      );
  double get distributedKg => deliveries.fold<double>(
        0,
        (total, delivery) => total + delivery.distributedKg,
      );
  double get unallocatedKg => receivedKg - distributedKg;
  int get schoolCount => deliveries
      .expand((delivery) => delivery.allocations)
      .where((allocation) => allocation.allocatedKg > 0)
      .map((allocation) => allocation.school)
      .toSet()
      .length;
}

String normalizedProductName(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

List<ProductSummary> summarizeProducts(Iterable<Delivery> deliveries) {
  final grouped = <String, List<Delivery>>{};
  for (final delivery in deliveries) {
    final key = normalizedProductName(delivery.product);
    grouped.putIfAbsent(key, () => []).add(delivery);
  }

  return grouped.values
      .map(
        (lots) => ProductSummary(
          name: lots.first.product.trim().replaceAll(RegExp(r'\s+'), ' '),
          deliveries: lots,
        ),
      )
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));
}
