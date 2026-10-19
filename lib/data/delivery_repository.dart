import '../domain/models.dart';
import '../domain/proportional_allocation.dart';

class DeliveryRepository {
  DeliveryRepository() {
    final today = DateTime.now();
    _deliveries.addAll([
      _seed(1, 'Cesta de verduras', 120, today, [
        const SchoolRequest(school: 'EMEF Manoel Paschoal', requestedKg: 50),
        const SchoolRequest(school: 'EMEF Padre Gabril', requestedKg: 45),
        const SchoolRequest(school: 'EMEF José Zacchi', requestedKg: 55),
      ]),
      _seed(2, 'Ovos caipira', 80, today.add(const Duration(days: 2)), [
        const SchoolRequest(school: 'EMEF Maria Aparecida', requestedKg: 30),
        const SchoolRequest(school: 'EMEF Pedro Vieira', requestedKg: 35),
        const SchoolRequest(school: 'EMEF Tereza Anexo', requestedKg: 25),
      ]),
      _seed(3, 'Leite da manhã', 150, today.add(const Duration(days: 5)), [
        const SchoolRequest(school: 'EMEF Tereza Sede', requestedKg: 65),
        const SchoolRequest(school: 'EMEF Antonio Esteves', requestedKg: 55),
        const SchoolRequest(school: 'EMEF Talma', requestedKg: 50),
      ]),
    ]);
  }

  final List<Delivery> _deliveries = [];

  List<Delivery> getAll() => List.unmodifiable(_deliveries);

  Delivery add({
    required String product,
    required double availableKg,
    required DateTime date,
    required List<SchoolRequest> requests,
  }) {
    final delivery = _seed(
      _deliveries.length + 1,
      product,
      availableKg,
      date,
      requests,
    );
    _deliveries.insert(0, delivery);
    return delivery;
  }

  void setStatus(int id, DeliveryStatus status) {
    final index = _deliveries.indexWhere((delivery) => delivery.id == id);
    if (index < 0) throw ArgumentError.value(id, 'id');
    _deliveries[index] = _deliveries[index].withStatus(status);
  }

  Delivery _seed(
    int id,
    String product,
    double availableKg,
    DateTime date,
    List<SchoolRequest> requests,
  ) =>
      Delivery(
        id: id,
        product: product,
        availableKg: availableKg,
        date: date,
        allocations: distributeProportionally(availableKg, requests),
      );
}
