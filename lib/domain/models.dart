enum DeliveryStatus { pending, completed }

class SchoolRequest {
  const SchoolRequest({required this.school, required this.requestedKg});

  final String school;
  final double requestedKg;
}

class BatchItem {
  const BatchItem(
      {required this.product,
      required this.availableKg,
      this.unitPriceCents,
      this.invoiceNumber});

  final String product;
  final double availableKg;
  final int? unitPriceCents;
  final String? invoiceNumber;
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
    this.unitPriceCents,
    this.invoiceNumber,
    this.lossKg,
  });

  final int id;
  final String product;
  final double availableKg;
  final DateTime date;
  final List<Allocation> allocations;
  final int batchId;
  final String batchName;
  final DeliveryStatus status;
  final int? unitPriceCents;
  final String? invoiceNumber;
  // null indica saldo ainda não classificado; zero indica sobra aproveitável.
  final double? lossKg;

  double get remainderKg =>
      (availableKg - distributedKg).clamp(0, availableKg).toDouble();
  double get surplusKg => lossKg == null
      ? 0
      : (remainderKg - lossKg!).clamp(0, availableKg).toDouble();

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
        unitPriceCents: unitPriceCents,
        invoiceNumber: invoiceNumber,
        lossKg: lossKg,
      );

  Delivery withAllocations(List<Allocation> value,
          {DeliveryStatus? status, double? recordedLossKg}) =>
      Delivery(
        id: id,
        product: product,
        availableKg: availableKg,
        date: date,
        allocations: List.unmodifiable(value),
        batchId: batchId,
        batchName: batchName,
        status: status ?? this.status,
        unitPriceCents: unitPriceCents,
        invoiceNumber: invoiceNumber,
        lossKg: recordedLossKg,
      );
}
