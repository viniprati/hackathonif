enum DeliveryStatus { pending, completed }

class SchoolRequest {
  const SchoolRequest({required this.school, required this.requestedKg});

  final String school;
  final double requestedKg;
}

class BatchItem {
  const BatchItem({required this.product, required this.availableKg});

  final String product;
  final double availableKg;
}

class Allocation {
  const Allocation({
    required this.school,
    required this.requestedKg,
    required this.allocatedKg,
  });

  final String school;
  final double requestedKg;
  final double allocatedKg;
}

class Delivery {
  const Delivery({
    required this.id,
    required this.product,
    required this.availableKg,
    required this.date,
    required this.allocations,
    this.batchId = 0,
    this.batchName = '',
    this.status = DeliveryStatus.pending,
  });

  final int id;
  final String product;
  final double availableKg;
  final DateTime date;
  final List<Allocation> allocations;
  final int batchId;
  final String batchName;
  final DeliveryStatus status;

  double get distributedKg =>
      allocations.fold<double>(0, (sum, item) => sum + item.allocatedKg);
  int get schoolCount =>
      allocations.where((item) => item.allocatedKg > 0).length;

  Delivery withStatus(DeliveryStatus value) => Delivery(
        id: id,
        product: product,
        availableKg: availableKg,
        date: date,
        allocations: allocations,
        batchId: batchId,
        batchName: batchName,
        status: value,
      );

  Delivery withAllocations(List<Allocation> value, {DeliveryStatus? status}) =>
      Delivery(
        id: id,
        product: product,
        availableKg: availableKg,
        date: date,
        allocations: List.unmodifiable(value),
        batchId: batchId,
        batchName: batchName,
        status: status ?? this.status,
      );
}
