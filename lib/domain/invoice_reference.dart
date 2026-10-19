class InvoiceItem {
  const InvoiceItem(
      this.food, this.quantityKg, this.unitPriceCents, this.totalCents);

  final String food;
  final double quantityKg;
  final int unitPriceCents;
  final int totalCents;
}

class InvoiceReference {
  const InvoiceReference({
    required this.number,
    required this.issuedAt,
    required this.totalCents,
    required this.items,
  });

  final String number;
  final DateTime issuedAt;
  final int totalCents;
  final List<InvoiceItem> items;
}

// Dados de produtos transcritos das DANFEs fornecidas. Sem dados pessoais
// de emitentes/destinatários. Não representam entrada automática no estoque.
final invoiceReferences = List<InvoiceReference>.unmodifiable([
  InvoiceReference(
    number: '190720001',
    issuedAt: DateTime(2026, 7, 19),
    totalCents: 3021674,
    items: const [
      InvoiceItem('Batata doce', 111, 572, 63492),
      InvoiceItem('Tomate', 2244.95, 1008, 2262910),
      InvoiceItem('Aipim', 198, 572, 113256),
      InvoiceItem('Limão', 60, 813, 48780),
      InvoiceItem('Limão orgânico', 60, 1057, 63420),
      InvoiceItem('Banana nanica', 218, 587, 127966),
      InvoiceItem('Banana prata orgânica', 430, 795, 341850),
    ],
  ),
  InvoiceReference(
    number: '260820001',
    issuedAt: DateTime(2026, 8, 26),
    totalCents: 749158,
    items: const [
      InvoiceItem('Chuchu', 692, 426, 294792),
      InvoiceItem('Banana da terra', 212, 832, 176384),
      InvoiceItem('Limão orgânico', 61.5, 1057, 65006),
      InvoiceItem('Banana prata', 348, 612, 212976),
    ],
  ),
]);
