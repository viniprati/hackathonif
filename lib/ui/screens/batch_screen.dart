import 'package:flutter/material.dart';

import '../../domain/batch_summary.dart';
import '../../domain/models.dart';
import '../theme.dart';
import '../view_models/delivery_view_model.dart';
import 'batch_forms.dart';

enum _BatchFilter { all, pending, completed }

class BatchesScreen extends StatefulWidget {
  const BatchesScreen({super.key, required this.viewModel});

  final DeliveryViewModel viewModel;

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  String _query = '';
  _BatchFilter _filter = _BatchFilter.all;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final batches = widget.viewModel.batches;
          final visible = batches.where((batch) {
            final query = _query.trim().toLowerCase();
            final matchesQuery = query.isEmpty ||
                batch.name.toLowerCase().contains(query) ||
                batch.deliveries.any((delivery) =>
                    delivery.product.toLowerCase().contains(query) ||
                    delivery.allocations.any((allocation) =>
                        allocation.school.toLowerCase().contains(query)));
            final matchesFilter = switch (_filter) {
              _BatchFilter.all => true,
              _BatchFilter.pending => !batch.isCompleted,
              _BatchFilter.completed => batch.isCompleted,
            };
            return matchesQuery && matchesFilter;
          }).toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Montantes',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: NativaColors.darkGreen,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Selecione o montante que deseja dividir.',
                            style: TextStyle(color: NativaColors.gray),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => NewBatchDialog(
                                viewModel: widget.viewModel,
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Cadastrar montante'),
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Buscar montantes',
                              hintText: 'Nome, alimento ou escola',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) =>
                                setState(() => _query = value),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              _chip('Todos', _BatchFilter.all),
                              _chip('Pendentes', _BatchFilter.pending),
                              _chip('Finalizados', _BatchFilter.completed),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${visible.length} ${visible.length == 1 ? 'montante' : 'montantes'}',
                            style: const TextStyle(color: NativaColors.gray),
                          ),
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
                            child: Text('Nenhum montante nesta seleção.'),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      sliver: SliverList.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: BatchCard(
                            batch: visible[index],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => BatchDetailsScreen(
                                  viewModel: widget.viewModel,
                                  batchId: visible[index].id,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );

  Widget _chip(String label, _BatchFilter filter) => FilterChip(
        label: Text(label),
        selected: _filter == filter,
        onSelected: (_) => setState(() => _filter = filter),
      );
}

class BatchCard extends StatelessWidget {
  const BatchCard({super.key, required this.batch, required this.onTap});

  final BatchSummary batch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 53,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: NativaColors.lightGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${batch.date.day}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: NativaColors.darkGreen,
                        ),
                      ),
                      Text(
                        monthNames[batch.date.month - 1].substring(0, 3),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batch.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        batch.deliveries
                            .map((item) =>
                                '${item.product} ${formatKg(item.availableKg)}')
                            .join(' • '),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: NativaColors.gray),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        batch.isCompleted
                            ? 'Finalizado'
                            : '${batch.pendingCount} alimentos pendentes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: batch.isCompleted
                              ? NativaColors.green
                              : NativaColors.earth,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );
}

class BatchDetailsScreen extends StatefulWidget {
  const BatchDetailsScreen({
    super.key,
    required this.viewModel,
    required this.batchId,
  });

  final DeliveryViewModel viewModel;
  final int batchId;

  @override
  State<BatchDetailsScreen> createState() => _BatchDetailsScreenState();
}

class _BatchDetailsScreenState extends State<BatchDetailsScreen> {
  int? _selectedDeliveryId;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final batch = widget.viewModel.batches.firstWhere(
            (item) => item.id == widget.batchId,
          );
          return Scaffold(
            appBar: AppBar(title: const Text('Montante')),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      batch.name,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: NativaColors.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(formatDate(batch.date)),
                    const SizedBox(height: 20),
                    const Text(
                      'Selecione o alimento que deseja separar',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    for (final delivery in batch.deliveries)
                      Card(
                        child: CheckboxListTile(
                          key: Key('batch-product-${delivery.id}'),
                          value: _selectedDeliveryId == delivery.id,
                          onChanged: (_) => setState(() {
                            _selectedDeliveryId =
                                _selectedDeliveryId == delivery.id
                                    ? null
                                    : delivery.id;
                          }),
                          title: Text(delivery.product),
                          subtitle: Text(
                            '${formatKg(delivery.availableKg)} • ${delivery.status == DeliveryStatus.completed ? 'Finalizado' : 'Pendente'}',
                          ),
                          secondary: const Icon(
                            Icons.eco_outlined,
                            color: NativaColors.green,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _selectedDeliveryId == null
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => AllocationScreen(
                                    viewModel: widget.viewModel,
                                    deliveryId: _selectedDeliveryId!,
                                  ),
                                ),
                              ),
                      icon: const Icon(Icons.call_split),
                      label: const Text('Dividir entre escolas'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}
