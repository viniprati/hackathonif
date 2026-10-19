import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/stock_report.dart';
import '../domain/product_summary.dart';
import 'theme.dart';

class ReportCharts extends StatelessWidget {
  const ReportCharts({super.key, required this.report});
  final StockReport report;

  @override
  Widget build(BuildContext context) {
    final portions = [
      ('Distribuído', report.distributedKg, NativaColors.green),
      ('Sobra aproveitável', report.surplusKg, const Color(0xFF327E93)),
      ('Perda', report.lossKg, NativaColors.terracotta),
      ('Aguardando rateio', report.pendingKg, NativaColors.yellow),
      ('Sem classificação', report.unclassifiedKg, NativaColors.gray),
    ];
    final foods = <String, (String, double, double)>{};
    for (final line in report.lines) {
      final key = normalizedProductName(line.delivery.product);
      final previous = foods[key];
      foods[key] = (
        line.delivery.product,
        (previous?.$2 ?? 0) + line.delivery.availableKg,
        (previous?.$3 ?? 0) + line.distributedKg
      );
    }
    final products = foods.values.toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    final maximum =
        products.fold<double>(0, (value, item) => math.max(value, item.$2));
    final schools = report.schools;
    final schoolMaximum =
        schools.fold<double>(0, (value, item) => math.max(value, item.kg));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Visão geral do período',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const Text(
          'Os gráficos mostram quantidades em kg do período selecionado. Rateio significa distribuição salva, sem comprovação de entrega.'),
      _ChartCard(
          title: 'Destino dos alimentos',
          child: report.receivedKg == 0
              ? const Text('Sem alimentos recebidos neste período.')
              : LayoutBuilder(builder: (context, constraints) {
                  final chart = Semantics(
                    container: true,
                    label:
                        'Gráfico de pizza: destino de ${formatKg(report.receivedKg)} recebidos. Valores na legenda.',
                    image: true,
                    child: SizedBox(
                        width: 180,
                        height: 180,
                        child: CustomPaint(
                            painter: _PiePainter(portions
                                .map((item) => (item.$2, item.$3))
                                .toList()))),
                  );
                  final legend = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total recebido: ${formatKg(report.receivedKg)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        for (final part in portions)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                        padding: const EdgeInsets.only(
                                            top: 5, right: 8),
                                        child: ColoredBox(
                                            color: part.$3,
                                            child: const SizedBox(
                                                width: 14, height: 14))),
                                    Expanded(
                                        child: Text(
                                            '${part.$1}: ${formatKg(part.$2)} (${(part.$2 / report.receivedKg * 100).toStringAsFixed(1).replaceAll('.', ',')}%)')),
                                  ])),
                      ]);
                  if (constraints.maxWidth /
                          (MediaQuery.textScalerOf(context).scale(14) / 14) <
                      600) {
                    return Column(
                        children: [chart, const SizedBox(height: 16), legend]);
                  }
                  return Row(children: [
                    chart,
                    const SizedBox(width: 24),
                    Expanded(child: legend)
                  ]);
                })),
      _ChartCard(
          title: 'Recebido e distribuído por alimento',
          child: products.isEmpty
              ? const Text('Sem alimentos neste período.')
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text(
                      'Colunas em kg, com a mesma escala para todos os alimentos. Deslize para ver os demais.'),
                  const Text('Verde escuro: recebido • Azul: distribuído'),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final product in products)
                              SizedBox(
                                width: 150 *
                                    (MediaQuery.textScalerOf(context)
                                            .scale(14) /
                                        14),
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: Semantics(
                                      container: true,
                                      label:
                                          '${product.$1}: ${formatKg(product.$2)} recebidos, ${formatKg(product.$3)} distribuídos',
                                      child: ExcludeSemantics(
                                          child: Column(children: [
                                        Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Expanded(
                                                  child: _ColumnBar(
                                                      value: product.$2,
                                                      maximum: maximum,
                                                      color:
                                                          NativaColors.green)),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                  child: _ColumnBar(
                                                      value: product.$3,
                                                      maximum: maximum,
                                                      color: const Color(
                                                          0xFF327E93))),
                                            ]),
                                        const Divider(height: 1),
                                        const SizedBox(height: 8),
                                        Text(product.$1,
                                            textAlign: TextAlign.center),
                                      ])),
                                    )),
                              ),
                          ])),
                ])),
      _ChartCard(
          title: 'Quantidade distribuída por escola',
          child: schools.isEmpty
              ? const Text('Sem distribuição salva neste período.')
              : Column(children: [
                  const Text(
                      'Barras horizontais em kg. Cada barra é comparada à maior distribuição do período.'),
                  for (final school in schools)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Semantics(
                          container: true,
                          label:
                              '${school.school}: ${formatKg(school.kg)} distribuídos',
                          child: ExcludeSemantics(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                Text(
                                    '${school.school} • ${formatKg(school.kg)}'),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                    value: schoolMaximum == 0
                                        ? 0
                                        : school.kg / schoolMaximum,
                                    minHeight: 18,
                                    backgroundColor: NativaColors.lightGreen,
                                    color: NativaColors.green),
                              ])),
                        )),
                ])),
    ]);
  }
}

class _ColumnBar extends StatelessWidget {
  const _ColumnBar(
      {required this.value, required this.maximum, required this.color});
  final double value;
  final double maximum;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(formatKg(value),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        SizedBox(
            height: 140,
            child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                    width: 28,
                    height: maximum == 0 ? 0 : 140 * value / maximum,
                    color: color))),
      ]);
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          child,
        ]),
      ));
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.portions);
  final List<(double, Color)> portions;
  @override
  void paint(Canvas canvas, Size size) {
    final total = portions.fold<double>(0, (sum, item) => sum + item.$1);
    if (total == 0) return;
    var start = -math.pi / 2;
    final bounds = Offset.zero & size;
    for (final portion in portions) {
      final sweep = portion.$1 / total * math.pi * 2;
      if (sweep > 0) {
        canvas.drawArc(
            bounds.deflate(4), start, sweep, true, Paint()..color = portion.$2);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) =>
      oldDelegate.portions != portions;
}
