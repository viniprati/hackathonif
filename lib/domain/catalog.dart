class FoodCatalogItem {
  const FoodCatalogItem(this.name, {this.priceCents, this.invoiceNumber});

  final String name;
  final int? priceCents;
  final String? invoiceNumber;
}

// Escolas provisórias já presentes no protótipo; aguardam cadastro oficial.
const schoolCatalog = ['IFES', 'Pinto Coelho', 'Darllin'];

const foodCatalog = [
  FoodCatalogItem('Aipim', priceCents: 572, invoiceNumber: '190720001'),
  FoodCatalogItem('Banana da terra',
      priceCents: 832, invoiceNumber: '260820001'),
  FoodCatalogItem('Banana nanica', priceCents: 587, invoiceNumber: '190720001'),
  FoodCatalogItem('Banana prata', priceCents: 612, invoiceNumber: '260820001'),
  FoodCatalogItem('Banana prata orgânica',
      priceCents: 795, invoiceNumber: '190720001'),
  FoodCatalogItem('Batata doce', priceCents: 572, invoiceNumber: '190720001'),
  FoodCatalogItem('Chuchu', priceCents: 426, invoiceNumber: '260820001'),
  FoodCatalogItem('Limão', priceCents: 813, invoiceNumber: '190720001'),
  FoodCatalogItem('Limão orgânico',
      priceCents: 1057, invoiceNumber: '260820001'),
  FoodCatalogItem('Tomate', priceCents: 1008, invoiceNumber: '190720001'),
];

FoodCatalogItem? findFood(String name) {
  for (final food in foodCatalog) {
    if (food.name == name) return food;
  }
  return null;
}
