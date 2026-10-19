import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/stock_report.dart';

String _money(int cents) {
  final whole = (cents ~/ 100).toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.');
  return 'R\$ $whole,${(cents % 100).toString().padLeft(2, '0')}';
}

String _kg(double value) =>
    '${value.toStringAsFixed(1).replaceAll('.', ',')} kg';
String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

class ReportPdf {
  ReportPdf({required this.regularFont, required this.boldFont});
  final ByteData regularFont;
  final ByteData boldFont;

  Future<Uint8List> build(StockReport report) async {
    final document =
        pw.Document(title: 'Nativa - Relatório gerencial', author: 'Nativa');
    final green = PdfColor.fromHex('#234631');
    pw.Widget heading(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
        child: pw.Text(title,
            style: pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold, color: green)));
    pw.Widget table(List<String> headers, List<List<String>> rows) =>
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerDecoration: pw.BoxDecoration(color: green),
          headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellPadding: const pw.EdgeInsets.all(5),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
        );
    document.addPage(pw.MultiPage(
      theme: pw.ThemeData.withFont(
          base: pw.Font.ttf(regularFont), bold: pw.Font.ttf(boldFont)),
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      maxPages: 200,
      footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Nativa - relatório gerencial, não é nota fiscal',
                    style: const pw.TextStyle(fontSize: 8)),
                pw.Text('${context.pageNumber}/${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8)),
              ])),
      build: (_) => [
        pw.Text('NATIVA | APROVISTA',
            style: pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold, color: green)),
        pw.Text(
            'Relatório ${report.period == ReportPeriod.week ? 'semanal' : 'mensal'} de alimentos e valores',
            style: const pw.TextStyle(fontSize: 14)),
        pw.SizedBox(height: 8),
        pw.Text(
            'Período: ${_date(report.window.start)} a ${_date(report.window.lastDay)}'),
        pw.SizedBox(height: 8),
        pw.Text(
            'Operação por data do montante. Notas de referência por data de emissão. Os totais das notas são apresentados separadamente e não são somados ao valor da operação.',
            style: const pw.TextStyle(fontSize: 9)),
        pw.Text(
            'Os dados iniciais do aplicativo são de demonstração. Valores representam alimentos a preços informados, sem registrar pagamentos ou receitas.',
            style: const pw.TextStyle(fontSize: 9)),
        heading('Resumo da operação'),
        table([
          'Situação',
          'Quantidade',
          'Valor com preço informado'
        ], [
          ['Recebido', _kg(report.receivedKg), _money(report.receivedCents)],
          [
            'Distribuição salva',
            _kg(report.distributedKg),
            _money(report.distributedCents)
          ],
          [
            'Sobra aproveitável',
            _kg(report.surplusKg),
            _money(report.surplusCents)
          ],
          ['Perda', _kg(report.lossKg), _money(report.lossCents)],
          [
            'Aguardando rateio',
            _kg(report.pendingKg),
            _money(report.pendingCents)
          ],
          [
            'Saldo sem classificação',
            _kg(report.unclassifiedKg),
            _money(report.unclassifiedCents)
          ],
        ]),
        pw.SizedBox(height: 8),
        pw.Text(
            'Taxa de perdas: ${(report.lossRate * 100).toStringAsFixed(2).replaceAll('.', ',')}% (kg perdidos / kg recebidos no período).',
            style: const pw.TextStyle(fontSize: 10)),
        if (report.unpricedCount > 0)
          pw.Text(
              'ATENÇÃO: ${report.unpricedCount} lote(s) sem preço. O subtotal financeiro não inclui esses lotes.',
              style:
                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        heading('Alimentos recebidos e preços por lote'),
        if (report.lines.isEmpty)
          pw.Text('Nenhum montante cadastrado no período.'),
        if (report.lines.isNotEmpty)
          table([
            'Alimento / montante',
            'Data',
            'Kg',
            'R\$/kg',
            'Valor',
            'NF ref.'
          ], [
            for (final line in report.lines)
              [
                '${line.delivery.product}\n${line.delivery.batchName}',
                _date(line.delivery.date),
                line.delivery.availableKg
                    .toStringAsFixed(1)
                    .replaceAll('.', ','),
                line.hasPrice
                    ? _money(line.delivery.unitPriceCents!)
                    : 'Sem preço',
                line.hasPrice ? _money(line.receivedCents) : 'Não incluído',
                line.delivery.invoiceNumber ?? 'Não vinculada',
              ],
          ]),
        heading('Distribuição, sobras e perdas por lote'),
        if (report.lines.isNotEmpty)
          table([
            'Alimento / lote',
            'Distribuído',
            'Sobra',
            'Perda',
            'Pendente',
            'Sem classif.'
          ], [
            for (final line in report.lines)
              [
                '${line.delivery.product} #${line.delivery.id}',
                _kg(line.distributedKg),
                _kg(line.surplusKg),
                _kg(line.lossKg),
                _kg(line.pendingKg),
                _kg(line.unclassifiedKg),
              ],
          ]),
        heading('Distribuição por escola'),
        if (report.schools.isEmpty)
          pw.Text('Nenhum rateio salvo para escolas neste período.'),
        if (report.schools.isNotEmpty)
          table([
            'Escola',
            'Quantidade',
            'Valor com preço informado'
          ], [
            for (final school in report.schools)
              [school.school, _kg(school.kg), _money(school.valueCents)],
          ]),
        heading('Notas fiscais de referência no período'),
        pw.Text(
            'Transcrição dos itens das DANFEs fornecidas; não cria entrada automática em montantes nem comprova pagamento.',
            style: const pw.TextStyle(fontSize: 9)),
        if (report.invoiceReferences.isEmpty)
          pw.Text('Nenhuma nota de referência emitida neste período.'),
        for (final invoice in report.invoiceReferences) ...[
          pw.SizedBox(height: 10),
          pw.Text(
              'NF ${invoice.number} | Emissão: ${_date(invoice.issuedAt)} | Total: ${_money(invoice.totalCents)}',
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          table([
            'Descrição',
            'Unidade',
            'Quantidade',
            'Valor unitário',
            'Valor total'
          ], [
            for (final item in invoice.items)
              [
                item.food,
                'kg',
                item.quantityKg.toStringAsFixed(4).replaceAll('.', ','),
                _money(item.unitPriceCents),
                _money(item.totalCents)
              ],
          ]),
        ],
        if (report.invoiceReferences.isNotEmpty)
          pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                  'Total das notas de referência: ${_money(report.invoicesCents)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
      ],
    ));
    return document.save();
  }
}
