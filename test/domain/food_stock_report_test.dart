import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nativa/data/report_pdf.dart';
import 'package:nativa/domain/models.dart';
import 'package:nativa/domain/stock_report.dart';

List<Delivery> foodReportDeliveries() => [
      Delivery(
          id: 1,
          product: 'Aipim',
          availableKg: 100,
          date: DateTime(2026, 10, 15),
          batchName: 'Primeiro montante',
          status: DeliveryStatus.completed,
          unitPriceCents: 200,
          lossKg: 10,
          allocations: const [
            Allocation(school: 'IFES', requestedKg: 60, allocatedKg: 60)
          ]),
      Delivery(
          id: 2,
          product: '  aipim  ',
          availableKg: 20,
          date: DateTime(2026, 10, 16),
          batchName: 'Segundo montante',
          unitPriceCents: 300,
          allocations: const []),
      Delivery(
          id: 3,
          product: 'Aipim',
          availableKg: 10,
          date: DateTime(2026, 10, 14),
          batchName: 'Terceiro montante',
          status: DeliveryStatus.completed,
          lossKg: 0,
          allocations: const [
            Allocation(school: 'Darllin', requestedKg: 5, allocatedKg: 5)
          ]),
      Delivery(
          id: 4,
          product: 'Aipim orgânico',
          availableKg: 5,
          date: DateTime(2026, 10, 15),
          unitPriceCents: 100,
          allocations: const []),
      Delivery(
          id: 5,
          product: 'Aipim',
          availableKg: 999,
          date: DateTime(2026, 9, 15),
          unitPriceCents: 100,
          allocations: const []),
    ];

void main() {
  test(
      'consolida alimentos, preços diferentes e valores parciais sem misturar variedades',
      () {
    final report = StockReport(
        period: ReportPeriod.month,
        reference: DateTime(2026, 10),
        deliveries: foodReportDeliveries(),
        invoices: const []);
    expect(report.foods.map((food) => food.name), ['Aipim', 'Aipim orgânico']);
    final food = report.foods.first;
    expect(food.receivedKg, 130);
    expect(food.distributedKg, 65);
    expect(food.surplusKg, 35);
    expect(food.lossKg, 10);
    expect(food.pendingKg, 20);
    expect(food.unclassifiedKg, 0);
    expect(food.lossRate, closeTo(10 / 130, 1e-9));
    expect(food.receivedCents, 26000);
    expect(food.distributedCents, 12000);
    expect(food.surplusCents, 6000);
    expect(food.lossCents, 2000);
    expect(food.pendingCents, 6000);
    expect(food.unpricedCount, 1);
    expect(food.schools.map((school) => school.school), ['Darllin', 'IFES']);
    expect(food.schools.map((school) => school.kg), [5, 60]);
    expect(food.schools.map((school) => school.valueCents), [0, 12000]);
    expect(report.foods.fold<double>(0, (sum, food) => sum + food.receivedKg),
        report.receivedKg);
    expect(report.foods.fold<int>(0, (sum, food) => sum + food.receivedCents),
        report.receivedCents);
    for (final food in report.foods) {
      expect(
          food.receivedKg,
          food.distributedKg +
              food.surplusKg +
              food.lossKg +
              food.pendingKg +
              food.unclassifiedKg);
      expect(
          food.receivedCents,
          food.distributedCents +
              food.surplusCents +
              food.lossCents +
              food.pendingCents +
              food.unclassifiedCents);
    }
  });

  test('agrupamento respeita a semana selecionada e períodos vazios', () {
    final deliveries = [
      ...foodReportDeliveries(),
      Delivery(
          id: 6,
          product: 'Aipim',
          availableKg: 1000,
          date: DateTime(2026, 10, 31),
          allocations: const [])
    ];
    final weekly = StockReport(
        period: ReportPeriod.week,
        reference: DateTime(2026, 10, 15),
        deliveries: deliveries,
        invoices: const []);
    expect(weekly.foods.first.receivedKg, 130);
    final empty = StockReport(
        period: ReportPeriod.month,
        reference: DateTime(2026, 11),
        deliveries: deliveries,
        invoices: const []);
    expect(empty.foods, isEmpty);
    expect(empty.receivedKg, 0);
  });

  test('gera PDF consolidado com recebimentos a preços diferentes', () async {
    final report = StockReport(
        period: ReportPeriod.month,
        reference: DateTime(2026, 10),
        deliveries: foodReportDeliveries(),
        invoices: const []);
    final pdf = await ReportPdf(
      regularFont: ByteData.sublistView(
          File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync()),
      boldFont: ByteData.sublistView(
          File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync()),
    ).build(report);
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(pdf.length, greaterThan(2000));
    // Artifact for inspecting the actual exported table with a PDF reader.
    Directory('build/reports').createSync(recursive: true);
    File('build/reports/relatorio_por_alimento.pdf').writeAsBytesSync(pdf);
  });
}
