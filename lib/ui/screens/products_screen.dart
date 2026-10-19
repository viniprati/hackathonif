import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/product_summary.dart';
import '../theme.dart';
import '../view_models/delivery_view_model.dart';
import 'delivery_screen.dart';

enum _ProductFilter { all, pending, completed }

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.viewModel});

  final DeliveryViewModel viewModel;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _query = '';
  _ProductFilter _filter = _ProductFilter.all;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final products = widget.viewModel.products;
          final visible = products.where((product) {
            final matchesSearch = product.key.contains(
              normalizedProductName(_query),
            );
            final matchesFilter = switch (_filter) {
              _ProductFilter.all => true,
              _ProductFilter.pending => product.pendingCount > 0,
              _ProductFilter.completed => product.completedCount > 0,
            };
            return matchesSearch && matchesFilter;
          }).toList();
          final received = products.fold<double>(
            0,
            (sum, product) => sum + product.receivedKg,
          );
          final distributed = products.fold<double>(
            0,
            (sum, product) => sum + product.distributedKg,
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                  final wide = constraints.maxWidth / scale >= 760;
                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Produtos',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: NativaColors.darkGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Acompanhe os alimentos recebidos e o rateio para as escolas.',
                                style: TextStyle(color: NativaColors.gray),
                              ),
                              const SizedBox(height: 20),
                              LayoutBuilder(
                                builder: (context, metricsConstraints) {
                                  final columns =
                                      scale > 1.3 ? 1 : (wide ? 3 : 2);
                                  final cardWidth =
                                      (metricsConstraints.maxWidth -
                                              10 * (columns - 1)) /
                                          columns;
                                  return Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      _MetricCard(
                                        width: cardWidth,
                                        icon: Icons.inventory_2_outlined,
                                        label: 'Produtos',
                                        value: '${products.length}',
                                        onTap: () => _showSummary(context,
                                            'Produtos cadastrados', products),
                                      ),
                                      _MetricCard(
                                        width: cardWidth,
                                        icon: Icons.scale_outlined,
                                        label: 'Recebido',
                                        value: formatKg(received),
                                        onTap: () => _showSummary(
                                            context,
                                            'Recebimentos por produto',
                                            products),
                                      ),
                                      _MetricCard(
                                        width: cardWidth,
                                        icon: Icons.pie_chart_outline,
                                        label: 'Rateado',
                                        value: formatKg(distributed),
                                        onTap: () => _showSummary(context,
                                            'Rateios por escola', products),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 22),
                              TextField(
                                decoration: const InputDecoration(
                                  hintText: 'Buscar produto',
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (value) =>
                                    setState(() => _query = value),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                children: [
                                  _filterChip('Todos', _ProductFilter.all),
                                  _filterChip(
                                    'Com pendências',
                                    _ProductFilter.pending,
                                  ),
                                  _filterChip(
                                    'Com concluídos',
                                    _ProductFilter.completed,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${visible.length} ${visible.length == 1 ? 'produto' : 'produtos'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: NativaColors.gray,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                      if (visible.isEmpty)
                        const SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverToBoxAdapter(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Nenhum produto encontrado nesta seleção.',
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                          sliver: scale > 1.3
                              ? SliverList.separated(
                                  itemCount: visible.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) => _ProductCard(
                                    product: visible[index],
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ProductDetailsScreen(
                                          viewModel: widget.viewModel,
                                          productKey: visible[index].key,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : SliverGrid.builder(
                                  itemCount: visible.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: wide ? 2 : 1,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    mainAxisExtent: 280 * scale,
                                  ),
                                  itemBuilder: (context, index) {
                                    final product = visible[index];
                                    return _ProductCard(
                                      product: product,
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => ProductDetailsScreen(
                                            viewModel: widget.viewModel,
                                            productKey: product.key,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      );

  void _showSummary(
      BuildContext context, String title, List<ProductSummary> products) {
    final schools = <String, double>{};
    for (final product in products) {
      for (final delivery in product.deliveries) {
        for (final allocation in delivery.allocations) {
          if (allocation.allocatedKg > 0) {
            schools.update(
                allocation.school, (kg) => kg + allocation.allocatedKg,
                ifAbsent: () => allocation.allocatedKg);
          }
        }
      }
    }
    showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(title),
              scrollable: true,
              content: SizedBox(
                  width: 600,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: title == 'Rateios por escola'
                        ? [
                            const Text(
                                'Quantidades rateadas nos lotes cadastrados, de todos os períodos.'),
                            if (schools.isEmpty)
                              const Text('Nenhum rateio registrado.'),
                            for (final school in schools.entries)
                              ListTile(
                                  title: Text(school.key),
                                  subtitle: Text(formatKg(school.value))),
                          ]
                        : [
                            const Text(
                                'Toque em um produto para ver seus lotes. Todos os períodos.'),
                            for (final product in products)
                              ListTile(
                                title: Text(product.name),
                                subtitle: Text(title == 'Produtos cadastrados'
                                    ? '${product.lotCount} lote(s) • ${product.pendingCount} pendente(s)'
                                    : '${formatKg(product.receivedKg)} recebidos'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                          builder: (_) => ProductDetailsScreen(
                                              viewModel: widget.viewModel,
                                              productKey: product.key)));
                                },
                              ),
                          ],
                  )),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Fechar'))
              ],
            ));
  }

  Widget _filterChip(String label, _ProductFilter filter) => FilterChip(
        label: Text(label),
        selected: _filter == filter,
        onSelected: (_) => setState(() => _filter = filter),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Card(
          margin: EdgeInsets.zero,
          color: NativaColors.lightGreen,
          child: InkWell(
            key: ValueKey('product-metric-$label'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: NativaColors.darkGreen, size: 22),
                  const SizedBox(height: 10),
                  Text(label, style: const TextStyle(fontSize: 12)),
                  const Text('Ver detalhes',
                      style: TextStyle(decoration: TextDecoration.underline)),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: NativaColors.darkGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final ProductSummary product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = product.receivedKg == 0
        ? 0.0
        : (product.distributedKg / product.receivedKg).clamp(0.0, 1.0);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.eco_outlined,
                    color: NativaColors.green,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${product.lotCount} ${product.lotCount == 1 ? 'lote' : 'lotes'} • ${product.schoolCount} escolas',
                style: const TextStyle(fontSize: 12, color: NativaColors.gray),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _Amount(
                          label: 'Recebido', value: product.receivedKg)),
                  Expanded(
                      child: _Amount(
                          label: 'Rateado', value: product.distributedKg)),
                  Expanded(
                      child: _Amount(
                          label: 'Sem distribuição',
                          value: product.unallocatedKg)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                  'Sobra: ${formatKg(product.surplusKg)} • Perda: ${formatKg(product.lossKg)}',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(6),
                backgroundColor: NativaColors.lightGreen,
                color: NativaColors.green,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _StatusPill(
                    label: '${product.pendingCount} pendentes',
                    color: NativaColors.yellow,
                  ),
                  _StatusPill(
                    label: '${product.completedCount} concluídos',
                    color: NativaColors.lightGreen,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: NativaColors.gray)),
          Text(
            formatKg(value),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Text(label, style: const TextStyle(fontSize: 11)),
        ),
      );
}

class ProductDetailsScreen extends StatelessWidget {
  const ProductDetailsScreen({
    super.key,
    required this.viewModel,
    required this.productKey,
  });

  final DeliveryViewModel viewModel;
  final String productKey;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final product = viewModel.products.firstWhere(
            (item) => item.key == productKey,
          );
          return Scaffold(
            appBar: AppBar(title: Text(product.name)),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: product.deliveries.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${product.lotCount} lotes • ${product.schoolCount} escolas',
                              style: const TextStyle(color: NativaColors.gray),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _DetailMetric('Recebido', product.receivedKg),
                                _DetailMetric('Rateado', product.distributedKg),
                                _DetailMetric(
                                    'Sem distribuição', product.unallocatedKg),
                                _DetailMetric(
                                    'Sobra aproveitável', product.surplusKg),
                                _DetailMetric('Perda', product.lossKg),
                              ],
                            ),
                          ],
                        ),
                      );
                    }
                    if (index == 1) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Lotes deste produto',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      );
                    }
                    final delivery = product.deliveries[index - 2];
                    final completed =
                        delivery.status == DeliveryStatus.completed;
                    return Card(
                      child: ListTile(
                        title: Text(
                            'Lote #${delivery.id} • ${formatDate(delivery.date)}'),
                        subtitle: Text(
                          '${formatKg(delivery.distributedKg)} rateados • ${delivery.schoolCount} escolas\n${completed ? 'Concluído' : 'Pendente'}',
                        ),
                        isThreeLine: true,
                        trailing: Icon(
                          completed ? Icons.check_circle : Icons.schedule,
                          color: completed
                              ? NativaColors.green
                              : NativaColors.terracotta,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DeliveryDetails(
                              viewModel: viewModel,
                              deliveryId: delivery.id,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric(this.label, this.value);

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 145,
        child: Card(
          color: NativaColors.lightGreen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 5),
                Text(
                  formatKg(value),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
}
