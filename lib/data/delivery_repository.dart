import '../domain/models.dart';
import '../domain/catalog.dart';
import '../domain/allocation_preview.dart';
import '../domain/invoice_reference.dart';
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
        'Batata doce',
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

  List<String> get knownSchools => List.unmodifiable(schoolCatalog);

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
        findFood(item.product) == null ||
        !item.availableKg.isFinite ||
        item.availableKg < 0.1 ||
        ((item.availableKg * 10) - (item.availableKg * 10).round()).abs() >
            1e-7 ||
        (item.unitPriceCents != null && item.unitPriceCents! < 0))) {
      throw ArgumentError('Informe alimentos e quantidades válidos.');
    }
    if (items.map((item) => item.product).toSet().length != items.length) {
      throw ArgumentError('Cada alimento deve aparecer uma vez no montante.');
    }
    for (final item in items) {
      if (item.invoiceNumber != null) {
        final references = invoiceReferences
            .where((invoice) => invoice.number == item.invoiceNumber);
        if (references.isEmpty ||
            !references.single.items.any((line) =>
                line.food == item.product &&
                line.unitPriceCents == item.unitPriceCents)) {
          throw ArgumentError(
              'O alimento ou preço não corresponde à nota selecionada.');
        }
      }
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
          unitPriceCents: item.unitPriceCents,
          invoiceNumber: item.invoiceNumber,
          useCatalogPrice: false,
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
    if (findFood(product) == null ||
        requests.any((request) => !schoolCatalog.contains(request.school))) {
      throw ArgumentError('Use apenas alimentos e escolas cadastrados.');
    }
    _validateRequestTotal(availableKg, requests);
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

  void _validateRequestTotal(double availableKg, List<SchoolRequest> requests) {
    final total =
        requests.fold<double>(0, (sum, item) => sum + item.requestedKg);
    if (!total.isFinite || total > availableKg + 1e-7) {
      throw ArgumentError(
          'A soma dos pedidos não pode ultrapassar o alimento recebido.');
    }
  }

  void setRequests(
    int id,
    List<SchoolRequest> requests, {
    bool remainderConfirmed = false,
    double? lossKg,
  }) {
    final index = _deliveries.indexWhere((delivery) => delivery.id == id);
    if (index < 0) throw ArgumentError.value(id, 'id');
    _validateRequestTotal(_deliveries[index].availableKg, requests);
    final normalizedNames = <String>{};
    final cleanRequests = <SchoolRequest>[];
    for (final request in requests) {
      final name = request.school.trim();
      if (!schoolCatalog.contains(name) ||
          !normalizedNames.add(name.toLowerCase()) ||
          !request.requestedKg.isFinite ||
          request.requestedKg < 0 ||
          ((request.requestedKg * 10) - (request.requestedKg * 10).round())
                  .abs() >
              1e-7) {
        throw ArgumentError('Revise os nomes e as quantidades das escolas.');
      }
      cleanRequests.add(
        SchoolRequest(school: name, requestedKg: request.requestedKg),
      );
    }
    final delivery = _deliveries[index];
    final completeRequests = [
      for (final school in schoolCatalog)
        SchoolRequest(
            school: school,
            requestedKg: cleanRequests
                .where((request) => request.school == school)
                .fold<double>(0, (sum, request) => sum + request.requestedKg)),
    ];
    final preview = AllocationPreview(delivery.availableKg, completeRequests);
    if (preview.remainderKg > 1e-7 && (!remainderConfirmed || lossKg == null)) {
      throw ArgumentError('Confirme e classifique o saldo antes de salvar.');
    }
    final recordedLoss = lossKg ?? 0;
    if (!recordedLoss.isFinite ||
        recordedLoss < 0 ||
        recordedLoss > preview.remainderKg + 1e-7) {
      throw ArgumentError(
          'A perda deve estar entre zero e o saldo do alimento.');
    }
    _deliveries[index] = delivery.withAllocations(
      preview.allocations,
      status: DeliveryStatus.completed,
      recordedLossKg: recordedLoss,
    );
  }

  void setStatus(int id, DeliveryStatus status) {
    final index = _deliveries.indexWhere((delivery) => delivery.id == id);
    if (index < 0) throw ArgumentError.value(id, 'id');
    if (status == DeliveryStatus.completed &&
        _deliveries[index].remainderKg > 1e-7 &&
        _deliveries[index].lossKg == null) {
      throw ArgumentError('Classifique o saldo antes de finalizar.');
    }
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
    int? unitPriceCents,
    String? invoiceNumber,
    bool useCatalogPrice = true,
  }) =>
      Delivery(
        id: id,
        batchId: batchId,
        batchName: batchName,
        product: product,
        availableKg: availableKg,
        date: date,
        allocations:
            List.unmodifiable(distributeProportionally(availableKg, requests)),
        status: status,
        unitPriceCents: useCatalogPrice
            ? unitPriceCents ?? findFood(product)?.priceCents
            : unitPriceCents,
        invoiceNumber: invoiceNumber,
        lossKg: status == DeliveryStatus.completed ? 0 : null,
      );
}
