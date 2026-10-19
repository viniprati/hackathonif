import 'models.dart';
import 'proportional_allocation.dart';

class AllocationPreview {
  AllocationPreview(double receivedKg, List<SchoolRequest> requests)
      : allocations =
            List.unmodifiable(distributeProportionally(receivedKg, requests)),
        receivedKg = receivedKg,
        requestedKg =
            requests.fold<double>(0, (sum, item) => sum + item.requestedKg);

  final double receivedKg;
  final double requestedKg;
  final List<Allocation> allocations;
  double get distributedKg =>
      allocations.fold<double>(0, (sum, item) => sum + item.allocatedKg);
  double get remainderKg =>
      (receivedKg - distributedKg).clamp(0, receivedKg).toDouble();
  double get shortageKg =>
      (requestedKg - distributedKg).clamp(0, double.infinity).toDouble();
}
