import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../theme.dart';
import '../view_models/delivery_view_model.dart';
import 'batch_forms.dart';

class BatchDetailsScreen extends StatelessWidget {
  const BatchDetailsScreen(
      {super.key, required this.viewModel, required this.batchId});

  final DeliveryViewModel viewModel;
  final int batchId;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final batch =
              viewModel.batches.firstWhere((batch) => batch.id == batchId);
          return Scaffold(
            appBar: AppBar(title: const Text('Montante')),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(batch.name,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: NativaColors.darkGreen)),
                    const SizedBox(height: 6),
                    Text(
                        '${formatDate(batch.date)} • ${formatKg(batch.receivedKg)} recebidos'),
                    const SizedBox(height: 6),
                    Text(batch.isCompleted
                        ? 'Finalizado'
                        : '${batch.pendingCount} alimentos pendentes'),
                    const SizedBox(height: 24),
                    const Text(
                        'Escolha um card para consultar o montante ou realizar o rateio.'),
                    const SizedBox(height: 16),
                    _InfoCard(
                      title: 'ALIMENTOS',
                      icon: Icons.eco_outlined,
                      subtitle:
                          '${batch.deliveries.length} alimentos neste montante',
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (dialogContext) => _InfoDialog(
                            title: 'Alimentos do montante',
                            children: [
                              for (final delivery in batch.deliveries)
                                Card(
                                    child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(delivery.product,
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold)),
                                        Text(
                                            '${formatKg(delivery.availableKg)} • ${delivery.status == DeliveryStatus.completed ? 'Finalizado' : 'Pendente'}'),
                                        Text(delivery.unitPriceCents == null
                                            ? 'Preço não informado'
                                            : '${formatMoney(delivery.unitPriceCents!)} / kg'),
                                        if (delivery.invoiceNumber != null)
                                          Text(
                                              'Referência: NF ${delivery.invoiceNumber}'),
                                        const SizedBox(height: 8),
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.of(dialogContext).pop();
                                            Navigator.of(context).push(
                                                MaterialPageRoute<void>(
                                                    builder: (_) =>
                                                        AllocationScreen(
                                                            viewModel:
                                                                viewModel,
                                                            deliveryId:
                                                                delivery.id)));
                                          },
                                          icon: const Icon(Icons.call_split),
                                          label: Text(
                                              '${delivery.status == DeliveryStatus.completed ? 'Editar' : 'Dividir'} ${delivery.product}'),
                                        ),
                                      ]),
                                )),
                            ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: 'ESCOLAS',
                      icon: Icons.school_outlined,
                      subtitle:
                          '${viewModel.knownSchools.length} escolas no cadastro definido',
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            _InfoDialog(title: 'Escolas e pedidos', children: [
                          for (final school in viewModel.knownSchools)
                            ListTile(
                              title: Text(school),
                              subtitle: Text([
                                for (final delivery in batch.deliveries)
                                  for (final allocation in delivery.allocations
                                      .where((item) =>
                                          item.school == school &&
                                          item.requestedKg > 0))
                                    '${delivery.product}: ${formatKg(allocation.requestedKg)} pedidos',
                              ].join('\n').isEmpty
                                  ? 'Sem pedido neste montante'
                                  : [
                                      for (final delivery in batch.deliveries)
                                        for (final allocation in delivery
                                            .allocations
                                            .where((item) =>
                                                item.school == school &&
                                                item.requestedKg > 0))
                                          '${delivery.product}: ${formatKg(allocation.requestedKg)} pedidos',
                                    ].join('\n')),
                            ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      title: 'DISTRIBUIÇÃO',
                      icon: Icons.local_shipping_outlined,
                      subtitle: 'Rateio, sobras e perdas por alimento',
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => _InfoDialog(
                            title: 'Distribuição do montante',
                            children: [
                              for (final delivery in batch.deliveries)
                                ListTile(
                                  title: Text(delivery.product),
                                  subtitle: Text(delivery.status ==
                                          DeliveryStatus.pending
                                      ? 'Aguardando rateio'
                                      : 'Distribuído: ${formatKg(delivery.distributedKg)}\nSobra: ${formatKg(delivery.surplusKg)} • Perda: ${formatKg(delivery.lossKg ?? 0)}'),
                                ),
                            ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap});
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
              backgroundColor: NativaColors.lightGreen,
              child: Icon(icon, color: NativaColors.darkGreen)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.open_in_new),
          onTap: onTap,
        ),
      );
}

class _InfoDialog extends StatelessWidget {
  const _InfoDialog({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children))),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'))
        ],
      );
}
