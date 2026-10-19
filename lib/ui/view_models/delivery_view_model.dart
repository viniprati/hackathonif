import 'package:flutter/foundation.dart';

import '../../data/delivery_repository.dart';
import '../../domain/batch_summary.dart';
import '../../domain/models.dart';
import '../../domain/product_summary.dart';
import '../../domain/catalog.dart';
import '../../domain/invoice_reference.dart';
import '../../domain/allocation_preview.dart';
import '../../domain/stock_report.dart';

class DeliveryViewModel extends ChangeNotifier {
  DeliveryViewModel(this._repository);

  final DeliveryRepository _repository;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime get selectedMonth => _selectedMonth;
  List<Delivery> get deliveries => _repository.getAll();
  List<BatchSummary> get batches => summarizeBatches(deliveries);
  List<String> get knownSchools => _repository.knownSchools;
  List<FoodCatalogItem> get foods => foodCatalog;
  List<InvoiceReference> get invoices => invoiceReferences;
  StockReport report(ReportPeriod period, DateTime reference) => StockReport(
        period: period,
        reference: reference,
        deliveries: deliveries,
        invoices: invoices,
      );
  AllocationPreview previewRequests(int id, List<SchoolRequest> requests) =>
      AllocationPreview(
          deliveries.firstWhere((item) => item.id == id).availableKg, requests);
  int get pendingBatchCount =>
      batches.where((batch) => !batch.isCompleted).length;
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

  int addBatch({
    required String name,
    required DateTime date,
    required List<BatchItem> items,
  }) {
    final id = _repository.addBatch(name: name, date: date, items: items);
    notifyListeners();
    return id;
  }

  void saveRequests(
    int deliveryId,
    List<SchoolRequest> requests, {
    bool remainderConfirmed = false,
    double? lossKg,
  }) {
    _repository.setRequests(deliveryId, requests,
        remainderConfirmed: remainderConfirmed, lossKg: lossKg);
    notifyListeners();
  }

  void setStatus(int id, DeliveryStatus status) {
    _repository.setStatus(id, status);
    notifyListeners();
  }
}
