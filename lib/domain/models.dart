enum DeliveryStatus { pending, completed }

class SchoolRequest {
  const SchoolRequest({required this.school, required this.requestedKg});

  final String school;
  final double requestedKg;
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
    this.status = DeliveryStatus.pending,
  });

  final int id;
  final String product;
  final double availableKg;
  final DateTime date;
  final List<Allocation> allocations;
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
        status: value,
      );
}
