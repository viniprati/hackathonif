import '../domain/models.dart';
import '../domain/catalog.dart';
import '../domain/allocation_preview.dart';
import '../domain/invoice_reference.dart';
import '../domain/proportional_allocation.dart';

class DeliveryRepository {
  DeliveryRepository({bool withExamples = true}) {
    if (!withExamples) {
      _nextDeliveryId = 1;
      _nextBatchId = 1;
      return;
    }
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
        participatingSchools: schools,
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
        participatingSchools: schools,
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
        participatingSchools: schools,
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
        participatingSchools: schools,
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
        participatingSchools: schools,
      ),
    ]);
  }

  final List<Delivery> _deliveries = [];
  int _nextDeliveryId = 6;
  int _nextBatchId = 3;

  int allocateBatchId() => _nextBatchId++;
  int allocateDeliveryId() => _nextDeliveryId++;

  void restoreAll(List<Delivery> values) {
    final ids = values.map((item) => item.id).toSet();
    if (ids.length != values.length ||
        values.any((item) => item.id <= 0 || item.batchId <= 0)) {
      throw const FormatException('Identificadores locais repetidos.');
    }
    _deliveries
      ..clear()
      ..addAll(values);
    _nextDeliveryId =
        values.fold<int>(0, (max, item) => item.id > max ? item.id : max) + 1;
    _nextBatchId = values.fold<int>(
            0, (max, item) => item.batchId > max ? item.batchId : max) +
        1;
  }

  void replaceBatch(int batchId, List<Delivery> values) {
    _deliveries.removeWhere((item) => item.batchId == batchId);
    _deliveries.insertAll(0, values);
  }

  List<Delivery> getAll() => List.unmodifiable(_deliveries);

  List<String> get knownSchools => List.unmodifiable(schoolCatalog);

  List<String> schoolsForDelivery(Delivery delivery) =>
      delivery.participatingSchools ?? knownSchools;

  int addBatch({
    required String name,
    required DateTime date,
    required List<BatchItem> items,
    List<String>? participatingSchools,
  }) {
    final selected = participatingSchools ?? knownSchools;
    if (selected.isEmpty ||
        selected.toSet().length != selected.length ||
        selected.any((school) => !schoolCatalog.contains(school))) {
      throw ArgumentError(
          'Selecione ao menos uma escola cadastrada, sem repetições.');
    }
    final schools =
        List<String>.unmodifiable(schoolCatalog.where(selected.contains));
    final batchName = name.trim();
    if (batchName.isEmpty || batchName.length > 120 || items.isEmpty) {
      throw ArgumentError('Informe o nome do montante e ao menos um alimento.');
    }
    if (items.any((item) =>
        findFood(item.product) == null ||
        !item.availableKg.isFinite ||
        item.availableKg < 0.1 ||
        item.availableKg > 1000000 ||
        ((item.availableKg * 10) - (item.availableKg * 10).round()).abs() >
            1e-7 ||
        (item.unitPriceCents != null &&
            (item.unitPriceCents! < 0 || item.unitPriceCents! > 1000000)))) {
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
          participatingSchools: schools,
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
    final schools = schoolsForDelivery(_deliveries[index]);
    _validateRequestTotal(_deliveries[index].availableKg, requests);
    final normalizedNames = <String>{};
    final cleanRequests = <SchoolRequest>[];
    for (final request in requests) {
      final name = request.school.trim();
      if (!schools.contains(name) ||
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
      for (final school in schools)
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
    List<String>? participatingSchools,
  }) =>
      Delivery(
        id: id,
        participatingSchools: participatingSchools,
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
