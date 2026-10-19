import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nativa/data/delivery_repository.dart';
import 'package:nativa/domain/catalog.dart';
import 'package:nativa/domain/invoice_reference.dart';
import 'package:nativa/domain/models.dart';
import 'package:nativa/domain/stock_report.dart';
import 'package:nativa/data/report_pdf.dart';

void main() {
  test('catalog contains exactly the foods transcribed from the invoices', () {
    expect(
        foodCatalog.map((food) => food.name).toSet(),
        invoiceReferences
            .expand((invoice) => invoice.items)
            .map((item) => item.food)
            .toSet());
    expect(foodCatalog, hasLength(10));
    for (final invoice in invoiceReferences) {
      expect(invoice.items.fold<int>(0, (sum, item) => sum + item.totalCents),
          invoice.totalCents);
      for (final item in invoice.items) {
        expect(valueInCents(item.quantityKg, item.unitPriceCents),
            item.totalCents);
      }
    }
    expect(invoiceReferences[0].totalCents, 3021674);
    expect(invoiceReferences[1].totalCents, 749158);
  });

  test('repository rejects unknown food and school and unconfirmed balances',
      () {
    final repo = DeliveryRepository();
    expect(
        () => repo.addBatch(
            name: 'Inválido',
            date: DateTime(2026),
            items: const [BatchItem(product: 'Inventado', availableKg: 10)]),
        throwsArgumentError);
    final before = repo.getAll().first;
    expect(
        () => repo.setRequests(
            1, const [SchoolRequest(school: 'Inventada', requestedKg: 20)]),
        throwsArgumentError);
    expect(
        () => repo.setRequests(
            1, const [SchoolRequest(school: 'IFES', requestedKg: 60)]),
        throwsArgumentError);
    expect(repo.getAll().first, same(before));
    expect(
        () => repo.setRequests(
            1, const [SchoolRequest(school: 'IFES', requestedKg: 60)],
            remainderConfirmed: true, lossKg: 41),
        throwsArgumentError);
    repo.setRequests(1, const [SchoolRequest(school: 'IFES', requestedKg: 60)],
        remainderConfirmed: true, lossKg: 10);
    final saved = repo.getAll().first;
    expect(saved.distributedKg, 60);
    expect(saved.lossKg, 10);
    expect(saved.surplusKg, 30);
    expect(saved.allocations.map((item) => item.school), schoolCatalog);
    expect(saved.allocations.last.requestedKg, 0);
    expect(saved.status, DeliveryStatus.completed);
  });

  test('missing prices stay missing and invoice links must match the item', () {
    final repo = DeliveryRepository();
    repo.addBatch(
        name: 'Sem preço',
        date: DateTime(2026),
        items: const [BatchItem(product: 'Aipim', availableKg: 10)]);
    expect(repo.getAll().first.unitPriceCents, isNull);
    expect(
        () => repo.addBatch(
                name: 'Preço incorreto',
                date: DateTime(2026),
                items: const [
                  BatchItem(
                      product: 'Aipim',
                      availableKg: 10,
                      unitPriceCents: 1,
                      invoiceNumber: '190720001')
                ]),
        throwsArgumentError);
  });

  test('stock and costs reconcile; pending stock is not treated as loss', () {
    final date = DateTime(2026, 10, 15);
    final report = StockReport(
        period: ReportPeriod.month,
        reference: date,
        invoices: invoiceReferences,
        deliveries: [
          Delivery(
              id: 1,
              product: 'Aipim',
              availableKg: 10,
              date: date,
              status: DeliveryStatus.completed,
              unitPriceCents: 333,
              lossKg: 1.1,
              allocations: const [
                Allocation(school: 'IFES', requestedKg: 3.3, allocatedKg: 3.3)
              ]),
          Delivery(
              id: 2,
              product: 'Tomate',
              availableKg: 20,
              date: date,
              unitPriceCents: 1008,
              allocations: const []),
          Delivery(
              id: 3,
              product: 'Chuchu',
              availableKg: 5,
              date: date,
              allocations: const []),
        ]);
    expect(report.receivedKg, 35);
    expect(report.pendingKg, 25);
    expect(report.lossKg, 1.1);
    expect(report.surplusKg, closeTo(5.6, 1e-9));
    expect(report.lossRate, closeTo(1.1 / 35, 1e-9));
    expect(report.receivedCents, 23490);
    expect(
        report.receivedCents,
        report.distributedCents +
            report.surplusCents +
            report.lossCents +
            report.pendingCents +
            report.unclassifiedCents);
    expect(
        report.receivedKg,
        closeTo(
            report.distributedKg +
                report.surplusKg +
                report.lossKg +
                report.pendingKg +
                report.unclassifiedKg,
            1e-9));
    expect(report.schools.single.valueCents, report.distributedCents);
    expect(report.unpricedCount, 1);
    expect(report.invoiceReferences, isEmpty);
  });

  test('week boundaries include year changes and exclude next Monday', () {
    final window = ReportingWindow(ReportPeriod.week, DateTime(2027, 1, 1));
    expect(window.start, DateTime(2026, 12, 28));
    expect(window.endExclusive, DateTime(2027, 1, 4));
    expect(window.contains(DateTime(2027, 1, 3, 23, 59)), isTrue);
    expect(window.contains(DateTime(2027, 1, 4)), isFalse);
    expect(ReportingWindow(ReportPeriod.month, DateTime(2028, 2, 10)).lastDay,
        DateTime(2028, 2, 29));
  });

  test('PDF is generated for empty operation and original invoice references',
      () async {
    final report = StockReport(
        period: ReportPeriod.month,
        reference: DateTime(2026, 8, 26),
        deliveries: const [],
        invoices: invoiceReferences);
    expect(report.invoiceReferences.single.number, '260820001');
    expect(report.invoicesCents, 749158);
    expect(report.receivedCents, 0);
    final pdf = await ReportPdf(
      regularFont: ByteData.sublistView(
          File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync()),
      boldFont: ByteData.sublistView(
          File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync()),
    ).build(report);
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(pdf.length, greaterThan(2000));
  });
}
