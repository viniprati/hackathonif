import 'dart:convert';

import 'models.dart';

bool _validQuantity(double kg) =>
    kg.isFinite &&
    kg >= 0 &&
    kg <= 1000000 &&
    (kg * 10 - (kg * 10).round()).abs() < 1e-7;

class SyncItem {
  SyncItem(
      {required this.product,
      required this.receivedKg,
      required this.status,
      required this.requests,
      this.unitPriceCents,
      this.invoiceNumber,
      this.lossKg});
  final String product;
  final double receivedKg;
  final DeliveryStatus status;
  final List<SchoolRequest> requests;
  final int? unitPriceCents;
  final String? invoiceNumber;
  final double? lossKg;

  factory SyncItem.fromJson(Map<String, dynamic> json) {
    final status = DeliveryStatus.values.byName(json['status'] as String);
    final quantity = (json['receivedKg'] as num).toDouble();
    final loss = (json['lossKg'] as num?)?.toDouble();
    final requests = (json['requests'] as List<dynamic>).map((raw) {
      final request = raw as Map<String, dynamic>;
      return SchoolRequest(
          school: request['school'] as String,
          requestedKg: (request['requestedKg'] as num).toDouble());
    }).toList()
      ..sort((a, b) => a.school.compareTo(b.school));
    final total =
        requests.fold<double>(0, (sum, item) => sum + item.requestedKg);
    if (!_validQuantity(quantity) ||
        quantity < 0.1 ||
        requests.any((item) => !_validQuantity(item.requestedKg)) ||
        total > quantity + 1e-7 ||
        (status == DeliveryStatus.completed &&
            (loss == null ||
                !_validQuantity(loss) ||
                loss < 0 ||
                loss > quantity - total + 1e-7)) ||
        (status == DeliveryStatus.pending && (loss != null || total != 0))) {
      throw const FormatException('Quantidades inconsistentes no montante.');
    }
    return SyncItem(
        product: json['product'] as String,
        receivedKg: quantity,
        unitPriceCents: json['unitPriceCents'] as int?,
        invoiceNumber: json['invoiceNumber'] as String?,
        status: status,
        requests: List.unmodifiable(requests),
        lossKg: loss);
  }
  Map<String, Object?> toJson() => {
        'product': product,
        'receivedKg': receivedKg,
        'unitPriceCents': unitPriceCents,
        'invoiceNumber': invoiceNumber,
        'status': status.name,
        'lossKg': lossKg,
        'requests': requests
            .map((item) =>
                {'school': item.school, 'requestedKg': item.requestedKg})
            .toList(),
      };
  Delivery toDelivery(int id, int batchId, BatchSnapshot batch) => Delivery(
        id: id,
        batchId: batchId,
        batchName: batch.name,
        date: DateTime.parse(batch.date),
        product: product,
        availableKg: receivedKg,
        status: status,
        unitPriceCents: unitPriceCents,
        invoiceNumber: invoiceNumber,
        lossKg: lossKg,
        participatingSchools: batch.schools,
        allocations: List.unmodifiable(requests.map((request) => Allocation(
            school: request.school,
            requestedKg: request.requestedKg,
            allocatedKg:
                status == DeliveryStatus.completed ? request.requestedKg : 0))),
      );
}

class BatchSnapshot {
  BatchSnapshot(
      {required this.name,
      required this.date,
      required this.schools,
      required this.items});
  final String name;
  final String date;
  final List<String> schools;
  final List<SyncItem> items;

  factory BatchSnapshot.fromJson(Map<String, dynamic> json) {
    final schools = (json['participatingSchools'] as List<dynamic>)
        .cast<String>()
        .toList()
      ..sort();
    final items = (json['items'] as List<dynamic>)
        .map((item) => SyncItem.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.product.compareTo(b.product));
    if (schools.isEmpty ||
        schools.toSet().length != schools.length ||
        items.isEmpty ||
        items.map((item) => item.product).toSet().length != items.length ||
        items.any((item) =>
            item.requests.length != schools.length ||
            item.requests.map((request) => request.school).toSet().length !=
                schools.length ||
            item.requests
                .any((request) => !schools.contains(request.school)))) {
      throw const FormatException(
          'Escolas ou alimentos inconsistentes no montante.');
    }
    final date = json['date'] as String;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        DateTime.parse(date).toIso8601String().substring(0, 10) != date) {
      throw const FormatException('Data inválida no montante.');
    }
    return BatchSnapshot(
        name: json['name'] as String,
        date: date,
        schools: List.unmodifiable(schools),
        items: List.unmodifiable(items));
  }

  factory BatchSnapshot.fromDeliveries(
      List<Delivery> deliveries, List<String> Function(Delivery) schoolsFor) {
    final first = deliveries.first;
    final schools = schoolsFor(first).toList()..sort();
    return BatchSnapshot.fromJson({
      'name': first.batchName,
      'date':
          '${first.date.year.toString().padLeft(4, '0')}-${first.date.month.toString().padLeft(2, '0')}-${first.date.day.toString().padLeft(2, '0')}',
      'participatingSchools': schools,
      'items': deliveries
          .map((delivery) => {
                'product': delivery.product,
                'receivedKg': delivery.availableKg,
                'unitPriceCents': delivery.unitPriceCents,
                'invoiceNumber': delivery.invoiceNumber,
                'status': delivery.status.name,
                'lossKg': delivery.status == DeliveryStatus.pending
                    ? null
                    : delivery.lossKg,
                'requests': schools
                    .map((school) => {
                          'school': school,
                          'requestedKg':
                              delivery.status == DeliveryStatus.pending
                                  ? 0.0
                                  : delivery.allocations
                                      .where((allocation) =>
                                          allocation.school == school)
                                      .fold<double>(
                                          0,
                                          (sum, allocation) =>
                                              sum + allocation.requestedKg)
                        })
                    .toList(),
              })
          .toList(),
    });
  }
  Map<String, Object?> toJson() => {
        'name': name,
        'date': date,
        'participatingSchools': schools,
        'items': items.map((item) => item.toJson()).toList()
      };
  String get fingerprint => jsonEncode(toJson());
  String get summary {
    final lines = [name, '$date • Escolas: ${schools.join(', ')}'];
    for (final item in items) {
      final price = item.unitPriceCents == null
          ? 'não definido'
          : 'R\$ ${(item.unitPriceCents! / 100).toStringAsFixed(2)}';
      lines.add(
          '${item.product}: ${item.receivedKg} kg recebidos • Preço/kg: $price • Perda: ${item.lossKg ?? 0} kg • ${item.status == DeliveryStatus.completed ? 'finalizado' : 'pendente'}');
      lines.addAll(item.requests
          .map((request) => '${request.school}: ${request.requestedKg} kg'));
      lines.add('');
    }
    return lines.join('\n');
  }
}

class RemoteBatch {
  RemoteBatch(
      {required this.id, required this.revision, required this.snapshot});
  final String id;
  final int revision;
  final BatchSnapshot snapshot;
  factory RemoteBatch.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final revision = json['revision'] as int;
    if (!RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(id) ||
        revision < 0) {
      throw const FormatException('Identificação inválida do montante.');
    }
    final items = (json['items'] as List<dynamic>).map((raw) {
      final item = raw as Map<String, dynamic>;
      final allocations = item['allocations'] as List<dynamic>;
      for (final raw in allocations) {
        final allocation = raw as Map<String, dynamic>;
        final allocated = (allocation['allocatedKg'] as num).toDouble();
        final requested = (allocation['requestedKg'] as num).toDouble();
        if (!_validQuantity(allocated) ||
            (item['status'] == 'completed' &&
                (allocated - requested).abs() > 1e-7) ||
            (item['status'] == 'pending' && allocated != 0)) {
          throw const FormatException('Distribuição inconsistente no banco.');
        }
      }
      return {...item, 'requests': allocations};
    }).toList();
    return RemoteBatch(
        id: id,
        revision: revision,
        snapshot: BatchSnapshot.fromJson({...json, 'items': items}));
  }
}
