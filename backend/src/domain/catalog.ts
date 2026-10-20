export const schools = ['IFES', 'Pinto Coelho', 'Darllin'] as const;
export const foods = [
  { name: 'Aipim', priceCents: 572, invoiceNumber: '190720001' },
  { name: 'Banana da terra', priceCents: 832, invoiceNumber: '260820001' },
  { name: 'Banana nanica', priceCents: 587, invoiceNumber: '190720001' },
  { name: 'Banana prata', priceCents: 612, invoiceNumber: '260820001' },
  { name: 'Banana prata orgânica', priceCents: 795, invoiceNumber: '190720001' },
  { name: 'Batata doce', priceCents: 572, invoiceNumber: '190720001' },
  { name: 'Chuchu', priceCents: 426, invoiceNumber: '260820001' },
  { name: 'Limão', priceCents: 813, invoiceNumber: '190720001' },
  { name: 'Limão orgânico', priceCents: 1057, invoiceNumber: '260820001' },
  { name: 'Tomate', priceCents: 1008, invoiceNumber: '190720001' },
] as const;
export const invoices = [
  {
    number: '190720001',
    issuedAt: '2026-07-19',
    totalCents: 3021674,
    items: [
      { food: 'Batata doce', quantityKg: 111, unitPriceCents: 572, totalCents: 63492 },
      { food: 'Tomate', quantityKg: 2244.95, unitPriceCents: 1008, totalCents: 2262910 },
      { food: 'Aipim', quantityKg: 198, unitPriceCents: 572, totalCents: 113256 },
      { food: 'Limão', quantityKg: 60, unitPriceCents: 813, totalCents: 48780 },
      { food: 'Limão orgânico', quantityKg: 60, unitPriceCents: 1057, totalCents: 63420 },
      { food: 'Banana nanica', quantityKg: 218, unitPriceCents: 587, totalCents: 127966 },
      { food: 'Banana prata orgânica', quantityKg: 430, unitPriceCents: 795, totalCents: 341850 },
    ],
  },
  {
    number: '260820001',
    issuedAt: '2026-08-26',
    totalCents: 749158,
    items: [
      { food: 'Chuchu', quantityKg: 692, unitPriceCents: 426, totalCents: 294792 },
      { food: 'Banana da terra', quantityKg: 212, unitPriceCents: 832, totalCents: 176384 },
      { food: 'Limão orgânico', quantityKg: 61.5, unitPriceCents: 1057, totalCents: 65006 },
      { food: 'Banana prata', quantityKg: 348, unitPriceCents: 612, totalCents: 212976 },
    ],
  },
] as const;
