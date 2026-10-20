import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../theme.dart';
import '../view_models/delivery_view_model.dart';
import 'batch_forms.dart';

class DeliveryDetails extends StatelessWidget {
  const DeliveryDetails({
    super.key,
    required this.viewModel,
    required this.deliveryId,
  });

  final DeliveryViewModel viewModel;
  final int deliveryId;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final delivery = viewModel.deliveries.firstWhere(
            (item) => item.id == deliveryId,
          );
          final requested = delivery.allocations.fold<double>(
            0,
            (sum, item) => sum + item.requestedKg,
          );
          final difference = delivery.availableKg - requested;
          final balance = delivery.status == DeliveryStatus.pending
              ? 'Aguardando rateio e classificação.'
              : delivery.remainderKg > 1e-7
                  ? delivery.lossKg == null
                      ? 'Saldo ainda não classificado: ${formatKg(delivery.remainderKg)}.'
                      : 'Sobra aproveitável: ${formatKg(delivery.surplusKg)}. Perda: ${formatKg(delivery.lossKg!)}.'
                  : difference < -0.05
                      ? 'Faltaram ${formatKg(-difference)}; o recebido foi rateado proporcionalmente.'
                      : 'Pedido e recebido estão equilibrados.';
          return Scaffold(
            appBar: AppBar(title: Text('Lote #${delivery.id}')),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    AccessibleHeading(
                      delivery.product,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.bold,
                        color: NativaColors.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        '${delivery.batchName} • ${formatDate(delivery.date)}'),
                    const SizedBox(height: 8),
                    Text(delivery.unitPriceCents == null
                        ? 'Preço não informado'
                        : 'Preço: ${formatMoney(delivery.unitPriceCents!)} / kg'),
                    Text(
                      delivery.status == DeliveryStatus.completed
                          ? 'Finalizado'
                          : 'Pendente',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: delivery.status == DeliveryStatus.completed
                            ? NativaColors.green
                            : NativaColors.earth,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Metric('Recebido', delivery.availableKg),
                        _Metric('Pedido', requested),
                        _Metric('Rateado', delivery.distributedKg),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: difference < -0.05
                          ? const Color(0xFFFFEAD3)
                          : NativaColors.lightGreen,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(balance),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Rateio por escola',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final allocation in delivery.allocations)
                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.school_outlined,
                            color: NativaColors.green,
                          ),
                          title: Text(allocation.school),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Pedido: ${formatKg(allocation.requestedKg)}'),
                              Text(
                                  'Distribuído: ${formatKg(allocation.allocatedKg)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AllocationScreen(
                            viewModel: viewModel,
                            deliveryId: delivery.id,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar rateio'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Container(
        width: 145,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NativaColors.lightGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatKg(value),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(label),
          ],
        ),
      );
}
