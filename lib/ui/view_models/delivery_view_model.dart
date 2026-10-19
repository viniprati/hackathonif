import 'package:flutter/foundation.dart';

import '../../data/delivery_repository.dart';
import '../../domain/models.dart';
import '../../domain/product_summary.dart';

class DeliveryViewModel extends ChangeNotifier {
  DeliveryViewModel(this._repository);

  final DeliveryRepository _repository;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime get selectedMonth => _selectedMonth;
  List<Delivery> get deliveries => _repository.getAll();
  List<ProductSummary> get products => summarizeProducts(deliveries);
  int get pendingCount => deliveries
      .where((delivery) => delivery.status == DeliveryStatus.pending)
      .length;
  double get totalDistributedKg => deliveries.fold<double>(
        0,
        (sum, delivery) => sum + delivery.distributedKg,
      );
  int get totalSchools => deliveries
      .expand(
        (delivery) =>
            delivery.allocations.map((allocation) => allocation.school),
      )
      .toSet()
      .length;

  void changeMonth(int offset) {
    _selectedMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + offset,
    );
    notifyListeners();
  }

  void addDelivery({
    required String product,
    required double availableKg,
    required DateTime date,
    required List<SchoolRequest> requests,
  }) {
    _repository.add(
      product: product,
      availableKg: availableKg,
      date: date,
      requests: requests,
    );
    notifyListeners();
  }

  void setStatus(int id, DeliveryStatus status) {
    _repository.setStatus(id, status);
    notifyListeners();
  }
}
