import 'invoice_reference.dart';
import 'models.dart';

enum ReportPeriod { week, month }

class ReportingWindow {
  ReportingWindow(ReportPeriod period, DateTime reference) {
    start = period == ReportPeriod.week
        ? DateTime(reference.year, reference.month,
            reference.day - reference.weekday + 1)
        : DateTime(reference.year, reference.month);
    endExclusive = period == ReportPeriod.week
        ? DateTime(start.year, start.month, start.day + 7)
        : DateTime(start.year, start.month + 1);
  }

  late final DateTime start;
  late final DateTime endExclusive;
  DateTime get lastDay =>
      DateTime(endExclusive.year, endExclusive.month, endExclusive.day - 1);
  bool contains(DateTime date) =>
      !date.isBefore(start) && date.isBefore(endExclusive);
}

int valueInCents(double kg, int unitPriceCents) =>
    (kg * unitPriceCents + 1e-7).round();

// Particiona centavos sem criar ou perder valor por arredondamento.
List<int> splitCents(int total, List<double> weights) {
  final sum = weights.fold<double>(0, (a, b) => a + b);
  if (sum <= 0) return List.filled(weights.length, 0);
  final shares = weights.map((weight) => total * weight / sum).toList();
  final values = shares.map((share) => share.floor()).toList();
  final order = List.generate(weights.length, (index) => index)
    ..sort((a, b) => (shares[b] - values[b]).compareTo(shares[a] - values[a]));
  var rest = total - values.fold<int>(0, (a, b) => a + b);
  for (final index in order) {
    if (rest <= 0) break;
    values[index]++;
    rest--;
  }
  return values;
}

class StockReportLine {
  StockReportLine(this.delivery) {
    final done = delivery.status == DeliveryStatus.completed;
    distributedKg = done ? delivery.distributedKg : 0;
    pendingKg = done ? 0 : delivery.availableKg;
    lossKg = done ? delivery.lossKg ?? 0 : 0;
    surplusKg = done && delivery.lossKg != null ? delivery.surplusKg : 0;
    unclassifiedKg = done && delivery.lossKg == null ? delivery.remainderKg : 0;
    values = List.unmodifiable(splitCents(receivedCents,
        [distributedKg, surplusKg, lossKg, pendingKg, unclassifiedKg]));
  }

  final Delivery delivery;
  late final double distributedKg;
  late final double pendingKg;
  late final double lossKg;
  late final double surplusKg;
  late final double unclassifiedKg;
  late final List<int> values;
  bool get hasPrice => delivery.unitPriceCents != null;
  int get receivedCents => hasPrice
      ? valueInCents(delivery.availableKg, delivery.unitPriceCents!)
      : 0;
  int get distributedCents => values[0];
  int get surplusCents => values[1];
  int get lossCents => values[2];
  int get pendingCents => values[3];
  int get unclassifiedCents => values[4];
}

class SchoolDistribution {
  const SchoolDistribution(this.school, this.kg, this.valueCents);
  final String school;
  final double kg;
  final int valueCents;
}

class StockReport {
  StockReport({
    required this.period,
    required DateTime reference,
    required Iterable<Delivery> deliveries,
    required Iterable<InvoiceReference> invoices,
  }) : window = ReportingWindow(period, reference) {
    lines = List.unmodifiable(deliveries
        .where((delivery) => window.contains(delivery.date))
        .map(StockReportLine.new));
    invoiceReferences = List.unmodifiable(
        invoices.where((invoice) => window.contains(invoice.issuedAt)));
  }

  final ReportPeriod period;
  final ReportingWindow window;
  late final List<StockReportLine> lines;
  late final List<InvoiceReference> invoiceReferences;
  double get receivedKg =>
      lines.fold<double>(0, (sum, line) => sum + line.delivery.availableKg);
  double get distributedKg =>
      lines.fold<double>(0, (sum, line) => sum + line.distributedKg);
  double get surplusKg =>
      lines.fold<double>(0, (sum, line) => sum + line.surplusKg);
  double get lossKg => lines.fold<double>(0, (sum, line) => sum + line.lossKg);
  double get pendingKg =>
      lines.fold<double>(0, (sum, line) => sum + line.pendingKg);
  double get unclassifiedKg =>
      lines.fold<double>(0, (sum, line) => sum + line.unclassifiedKg);
  double get lossRate => receivedKg == 0 ? 0 : lossKg / receivedKg;
  int get receivedCents =>
      lines.fold<int>(0, (sum, line) => sum + line.receivedCents);
  int get distributedCents =>
      lines.fold<int>(0, (sum, line) => sum + line.distributedCents);
  int get surplusCents =>
      lines.fold<int>(0, (sum, line) => sum + line.surplusCents);
  int get lossCents => lines.fold<int>(0, (sum, line) => sum + line.lossCents);
  int get pendingCents =>
      lines.fold<int>(0, (sum, line) => sum + line.pendingCents);
  int get unclassifiedCents =>
      lines.fold<int>(0, (sum, line) => sum + line.unclassifiedCents);
  int get unpricedCount => lines.where((line) => !line.hasPrice).length;
  int get invoicesCents => invoiceReferences.fold<int>(
      0, (sum, invoice) => sum + invoice.totalCents);

  List<SchoolDistribution> get schools {
    final kg = <String, double>{};
    final values = <String, int>{};
    for (final line in lines
        .where((line) => line.delivery.status == DeliveryStatus.completed)) {
      final allocations = line.delivery.allocations;
      final amounts = splitCents(line.distributedCents,
          allocations.map((allocation) => allocation.allocatedKg).toList());
      for (var i = 0; i < allocations.length; i++) {
        final allocation = allocations[i];
        if (allocation.allocatedKg <= 0) continue;
        kg.update(allocation.school, (value) => value + allocation.allocatedKg,
            ifAbsent: () => allocation.allocatedKg);
        values.update(allocation.school, (value) => value + amounts[i],
            ifAbsent: () => amounts[i]);
      }
    }
    final names = kg.keys.toList()..sort();
    return [
      for (final name in names)
        SchoolDistribution(name, kg[name]!, values[name]!)
    ];
  }
}
