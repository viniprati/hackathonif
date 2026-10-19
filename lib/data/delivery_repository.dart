import '../domain/models.dart';
import '../domain/proportional_allocation.dart';

class DeliveryRepository {
  DeliveryRepository() {
    final today = DateTime.now();
    final octoberLikeDate = DateTime(today.year, today.month, 15);
    final previousMonthDate = DateTime(today.year, today.month - 1, 11);
    const schools = ['IFES', 'Pinto Coelho', 'Darllin'];
    _deliveries.addAll([
      _seed(
        1,
        1,
        'Dia das Crianças',
        'Aipim',
        100,
        octoberLikeDate,
        [
          for (final school in schools)
            SchoolRequest(school: school, requestedKg: 0)
        ],
      ),
      _seed(
        2,
        1,
        'Dia das Crianças',
        'Chuchu',
        30,
        octoberLikeDate,
        [
          for (final school in schools)
            SchoolRequest(school: school, requestedKg: 0)
        ],
      ),
      _seed(
        3,
        1,
        'Dia das Crianças',
        'Ervilha',
        30,
        octoberLikeDate,
        [
          for (final school in schools)
            SchoolRequest(school: school, requestedKg: 0)
        ],
      ),
      _seed(
        4,
        2,
        'Montante Especial',
        'Banana prata',
        80,
        previousMonthDate,
        const [
          SchoolRequest(school: 'IFES', requestedKg: 35),
          SchoolRequest(school: 'Pinto Coelho', requestedKg: 25),
          SchoolRequest(school: 'Darllin', requestedKg: 20),
        ],
        status: DeliveryStatus.completed,
      ),
      _seed(
        5,
        2,
        'Montante Especial',
        'Tomate',
        50,
        previousMonthDate,
        const [
          SchoolRequest(school: 'IFES', requestedKg: 25),
          SchoolRequest(school: 'Pinto Coelho', requestedKg: 25),
        ],
        status: DeliveryStatus.completed,
      ),
    ]);
  }

  final List<Delivery> _deliveries = [];
  int _nextDeliveryId = 6;
  int _nextBatchId = 3;

  List<Delivery> getAll() => List.unmodifiable(_deliveries);

  List<String> get knownSchools {
    final schools = _deliveries
        .expand((delivery) => delivery.allocations)
        .map((allocation) => allocation.school)
        .toSet()
        .toList();
    schools.sort();
    return List.unmodifiable(schools);
  }

  int addBatch({
    required String name,
    required DateTime date,
    required List<BatchItem> items,
  }) {
    final batchName = name.trim();
    if (batchName.isEmpty || items.isEmpty) {
      throw ArgumentError('Informe o nome do montante e ao menos um alimento.');
    }
    if (items.any((item) =>
        item.product.trim().isEmpty ||
        !item.availableKg.isFinite ||
        item.availableKg < 0.1)) {
      throw ArgumentError('Informe alimentos e quantidades válidos.');
    }
    final batchId = _nextBatchId++;
    final schools = knownSchools;
    for (final item in items.reversed) {
      _deliveries.insert(
        0,
        _seed(
          _nextDeliveryId++,
          batchId,
          batchName,
          item.product.trim(),
          item.availableKg,
          date,
          [
            for (final school in schools)
              SchoolRequest(school: school, requestedKg: 0)
          ],
        ),
      );
    }
    return batchId;
  }

  Delivery add({
    required String product,
    required double availableKg,
    required DateTime date,
    required List<SchoolRequest> requests,
  }) {
    final delivery = _seed(
      _nextDeliveryId++,
      _nextBatchId++,
      'Distribuição de $product',
      product,
      availableKg,
      date,
      requests,
    );
    _deliveries.insert(0, delivery);
    return delivery;
  }

  void setRequests(int id, List<SchoolRequest> requests) {
    final index = _deliveries.indexWhere((delivery) => delivery.id == id);
    if (index < 0) throw ArgumentError.value(id, 'id');
    final normalizedNames = <String>{};
    final cleanRequests = <SchoolRequest>[];
    for (final request in requests) {
      final name = request.school.trim();
      if (name.isEmpty ||
          !normalizedNames.add(name.toLowerCase()) ||
          !request.requestedKg.isFinite ||
          request.requestedKg < 0 ||
          (request.requestedKg > 0 && request.requestedKg < 0.1)) {
        throw ArgumentError('Revise os nomes e as quantidades das escolas.');
      }
      cleanRequests.add(
        SchoolRequest(school: name, requestedKg: request.requestedKg),
      );
    }
    if (requests.isEmpty ||
        !requests.any((request) => request.requestedKg > 0)) {
      throw ArgumentError('Informe ao menos um pedido maior que zero.');
    }
    final delivery = _deliveries[index];
    _deliveries[index] = delivery.withAllocations(
      distributeProportionally(delivery.availableKg, cleanRequests),
      status: DeliveryStatus.completed,
    );
  }

  void setStatus(int id, DeliveryStatus status) {
    final index = _deliveries.indexWhere((delivery) => delivery.id == id);
    if (index < 0) throw ArgumentError.value(id, 'id');
    _deliveries[index] = _deliveries[index].withStatus(status);
  }

  Delivery _seed(
    int id,
    int batchId,
    String batchName,
    String product,
    double availableKg,
    DateTime date,
    List<SchoolRequest> requests, {
    DeliveryStatus status = DeliveryStatus.pending,
  }) =>
      Delivery(
        id: id,
        batchId: batchId,
        batchName: batchName,
        product: product,
        availableKg: availableKg,
        date: date,
        allocations: distributeProportionally(availableKg, requests),
        status: status,
      );
}
