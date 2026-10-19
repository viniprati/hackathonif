import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../data/report_pdf.dart';
import '../../domain/stock_report.dart';
import '../../domain/invoice_reference.dart';
import '../theme.dart';
import '../report_charts.dart';
import '../view_models/delivery_view_model.dart';
import 'delivery_screen.dart';

Future<Uint8List> _buildPdf(StockReport report) async {
  final fonts = await Future.wait([
    rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
  ]);
  return ReportPdf(regularFont: fonts[0], boldFont: fonts[1]).build(report);
}

String _filename(StockReport report) =>
    'nativa_${report.period.name}_${report.window.start.toIso8601String().substring(0, 10)}.pdf';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.viewModel});
  final DeliveryViewModel viewModel;
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.month;
  DateTime _reference = DateTime.now();
  bool _downloading = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final report = widget.viewModel.report(_period, _reference);
          return Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: report.lines.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Relatórios',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: NativaColors.darkGreen)),
                        const SizedBox(height: 6),
                        const Text(
                            'Escolha uma semana ou mês para acompanhar as quantidades e os valores.'),
                        const SizedBox(height: 16),
                        SegmentedButton<ReportPeriod>(
                          segments: const [
                            ButtonSegment(
                                value: ReportPeriod.week,
                                label: Text('Semanal')),
                            ButtonSegment(
                                value: ReportPeriod.month,
                                label: Text('Mensal'))
                          ],
                          selected: {_period},
                          onSelectionChanged: (value) =>
                              setState(() => _period = value.single),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          IconButton(
                              tooltip: 'Período anterior',
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () => _move(-1)),
                          Expanded(
                              child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final date = await showDatePicker(
                                        context: context,
                                        initialDate: _reference,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100));
                                    if (date != null && mounted) {
                                      setState(() => _reference = date);
                                    }
                                  },
                                  icon:
                                      const Icon(Icons.calendar_month_outlined),
                                  label: Text(
                                      '${formatDate(report.window.start)} a ${formatDate(report.window.lastDay)}',
                                      textAlign: TextAlign.center))),
                          IconButton(
                              tooltip: 'Próximo período',
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () => _move(1)),
                        ]),
                        const SizedBox(height: 12),
                        ReportCharts(report: report),
                        const SizedBox(height: 16),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title:
                              const Text('Quantidades e valores em detalhes'),
                          subtitle: const Text(
                              'Valores de alimentos com preço informado'),
                          children: [
                            LayoutBuilder(builder: (context, constraints) {
                              final scale =
                                  MediaQuery.textScalerOf(context).scale(14) /
                                      14;
                              final columns = scale > 1.3
                                  ? 1
                                  : (constraints.maxWidth >= 750 ? 3 : 2);
                              final width =
                                  (constraints.maxWidth - 10 * (columns - 1)) /
                                      columns;
                              return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _Metric(
                                        width,
                                        'Recebido',
                                        report.receivedKg,
                                        report.receivedCents),
                                    _Metric(
                                        width,
                                        'Distribuído',
                                        report.distributedKg,
                                        report.distributedCents),
                                    _Metric(width, 'Sobra aproveitável',
                                        report.surplusKg, report.surplusCents),
                                    _Metric(width, 'Perda', report.lossKg,
                                        report.lossCents),
                                    _Metric(width, 'Aguardando rateio',
                                        report.pendingKg, report.pendingCents),
                                    _Metric(
                                        width,
                                        'Sem classificação',
                                        report.unclassifiedKg,
                                        report.unclassifiedCents),
                                  ]);
                            }),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                            'Taxa de perdas: ${(report.lossRate * 100).toStringAsFixed(2).replaceAll('.', ',')}%',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text(
                            'Cálculo: kg perdidos ÷ kg recebidos no período. Pendências e saldos não classificados não são perdas.',
                            style: TextStyle(
                                fontSize: 12, color: NativaColors.gray)),
                        if (report.unpricedCount > 0)
                          Card(
                              color:
                                  NativaColors.yellow.withValues(alpha: 0.25),
                              child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                      '${report.unpricedCount} lote(s) sem preço informado. O subtotal financeiro está incompleto.'))),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        ReportPreviewScreen(report: report))),
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('Visualizar PDF')),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed:
                              _downloading ? null : () => _download(report),
                          icon: const Icon(Icons.download_outlined),
                          label: Text(
                              _downloading ? 'Gerando PDF...' : 'Baixar PDF'),
                        ),
                        const SizedBox(height: 22),
                        const Text('Detalhamento dos lotes',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text(
                            'Abra um lote para conferir quantidades, valores e o rateio.'),
                        if (report.lines.isEmpty)
                          const Text(
                              'Nenhum montante cadastrado neste período.'),
                        const SizedBox(height: 8),
                      ]);
                }
                if (index == report.lines.length + 1) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 18),
                        const Text('Valores dos alimentos por escola',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        if (report.schools.isEmpty)
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Sem rateios salvos neste período.')),
                        for (final school in report.schools)
                          Card(
                              child: ListTile(
                                  title: Text(school.school),
                                  subtitle: Text(formatKg(school.kg)),
                                  trailing:
                                      Text(formatMoney(school.valueCents)))),
                        const SizedBox(height: 20),
                        const Text('Notas fiscais de referência',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text(
                            'Itens e valores transcritos das duas DANFEs fornecidas. São referências separadas dos montantes; não entram duas vezes nos totais.'),
                        const SizedBox(height: 8),
                        Text(
                            'No período: ${report.invoiceReferences.length} notas • ${formatMoney(report.invoicesCents)}'),
                        if (report.invoiceReferences.isEmpty)
                          const Text(
                              'Nenhuma nota de referência neste período.'),
                        for (final invoice in report.invoiceReferences)
                          Card(
                              child: Column(children: [
                            ListTile(
                                title: Text('NF ${invoice.number}'),
                                subtitle: Text(
                                    '${formatDate(invoice.issuedAt)} • ${formatMoney(invoice.totalCents)}'),
                                trailing: const Icon(Icons.open_in_new),
                                onTap: () => _showInvoice(context, invoice)),
                            TextButton(
                                onPressed: () => setState(
                                    () => _reference = invoice.issuedAt),
                                child: const Text('Exibir período desta nota')),
                          ])),
                        const SizedBox(height: 12),
                        const Text(
                            'Os dados iniciais são de demonstração e ficam em memória. Os valores da operação representam alimentos, não receitas, pagamentos ou saldo bancário.',
                            style: TextStyle(
                                fontSize: 12, color: NativaColors.gray)),
                      ]);
                }
                final line = report.lines[index - 1];
                return Card(
                    child: ExpansionTile(
                  title: Text(line.delivery.product,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${line.delivery.batchName} • ${formatDate(line.delivery.date)}'),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    Text(
                        '${line.delivery.batchName} • ${formatDate(line.delivery.date)}\nRecebido: ${formatKg(line.delivery.availableKg)}\nDistribuído: ${formatKg(line.distributedKg)} • Sobra: ${formatKg(line.surplusKg)}\nPerda: ${formatKg(line.lossKg)} • Pendente: ${formatKg(line.pendingKg)}\n${line.hasPrice ? '${formatMoney(line.delivery.unitPriceCents!)} / kg • ${formatMoney(line.receivedCents)}' : 'Preço não informado'}'),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => DeliveryDetails(
                                  viewModel: widget.viewModel,
                                  deliveryId: line.delivery.id))),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Ver rateio do lote'),
                    ),
                  ],
                ));
              },
            ),
          ));
        },
      );

  void _move(int offset) => setState(() {
        _reference = _period == ReportPeriod.week
            ? DateTime(
                _reference.year, _reference.month, _reference.day + offset * 7)
            : DateTime(_reference.year, _reference.month + offset);
      });

  Future<void> _download(StockReport report) async {
    setState(() => _downloading = true);
    try {
      final bytes = await _buildPdf(report);
      await Printing.sharePdf(bytes: bytes, filename: _filename(report));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Não foi possível baixar o PDF. Tente novamente.')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _showInvoice(BuildContext context, InvoiceReference invoice) =>
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('NF ${invoice.number}'),
          content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Text('Emissão: ${formatDate(invoice.issuedAt)}'),
                    for (final item in invoice.items)
                      ListTile(
                          title: Text(item.food),
                          subtitle: Text(
                              '${item.quantityKg.toStringAsFixed(4).replaceAll('.', ',')} kg × ${formatMoney(item.unitPriceCents)}'),
                          trailing: Text(formatMoney(item.totalCents))),
                    Text('Total original: ${formatMoney(invoice.totalCents)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'))
          ],
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.width, this.label, this.kg, this.cents);
  final double width;
  final String label;
  final double kg;
  final int cents;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: width,
      child: Card(
          margin: EdgeInsets.zero,
          color: NativaColors.lightGreen,
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12)),
                    Text(formatKg(kg),
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.bold)),
                    Text(formatMoney(cents),
                        style: const TextStyle(fontSize: 12)),
                  ]))));
}

class ReportPreviewScreen extends StatelessWidget {
  const ReportPreviewScreen({super.key, required this.report});
  final StockReport report;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Relatório em PDF')),
        body: PdfPreview(
          pdfFileName: _filename(report),
          canChangePageFormat: false,
          canChangeOrientation: false,
          build: (_) => _buildPdf(report),
        ),
      );
}
