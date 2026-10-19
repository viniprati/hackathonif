import 'models.dart';
import 'proportional_allocation.dart';

class AllocationPreview {
  AllocationPreview(double receivedKg, List<SchoolRequest> requests)
      : allocations = List.unmodifiable(
            requests.fold<double>(0, (sum, item) => sum + item.requestedKg) >
                    receivedKg + 1e-7
                ? [
                    for (final request in requests)
                      Allocation(
                          school: request.school,
                          requestedKg: request.requestedKg,
                          allocatedKg: 0)
                  ]
                : distributeProportionally(receivedKg, requests)),
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
      (requestedKg - receivedKg).clamp(0, double.infinity).toDouble();
}
