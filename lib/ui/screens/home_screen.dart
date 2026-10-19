import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../theme.dart';
import '../view_models/delivery_view_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.viewModel,
    required this.openDeliveries,
  });
  final DeliveryViewModel viewModel;
  final VoidCallback openDeliveries;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final pending = viewModel.deliveries
              .where((delivery) => delivery.status == DeliveryStatus.pending)
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Olá, Seu José!',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Aprovista • seu painel de entregas',
                              style: TextStyle(color: NativaColors.gray),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ver entregas pendentes',
                        onPressed: openDeliveries,
                        icon: const Icon(Icons.notifications_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: ListTile(
                      onTap: openDeliveries,
                      leading: const Icon(
                        Icons.local_shipping_outlined,
                        color: NativaColors.earth,
                      ),
                      title:
                          Text('${viewModel.pendingCount} entregas pendentes'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _Calendar(viewModel: viewModel),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Próximas entregas',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (pending.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Todas as entregas foram concluídas.'),
                      ),
                    ),
                  ...pending.take(3).map(
                        (delivery) => Card(
                          color: NativaColors.lightGreen,
                          child: ListTile(
                            onTap: openDeliveries,
                            leading: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  monthNames[delivery.date.month - 1]
                                      .substring(0, 3)
                                      .toUpperCase(),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                Text(
                                  '${delivery.date.day}',
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            title: Text(delivery.product),
                            subtitle: Text(
                              '${delivery.schoolCount} escolas • ${formatKg(delivery.distributedKg)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ),
                      ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Rateado',
                          value: formatKg(viewModel.totalDistributedKg),
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Escolas',
                          value: '${viewModel.totalSchools}',
                          icon: Icons.school_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: NativaColors.green),
              const SizedBox(height: 10),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(label, style: const TextStyle(color: NativaColors.gray)),
            ],
          ),
        ),
      );
}

class _Calendar extends StatelessWidget {
  const _Calendar({required this.viewModel});
  final DeliveryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final month = viewModel.selectedMonth;
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday % 7;
    final events = viewModel.deliveries
        .where(
          (delivery) =>
              delivery.date.year == month.year &&
              delivery.date.month == month.month,
        )
        .toList();
    final today = DateTime.now();
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Mês anterior',
              onPressed: () => viewModel.changeMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${monthNames[month.month - 1][0].toUpperCase()}${monthNames[month.month - 1].substring(1)} ${month.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: 'Próximo mês',
              onPressed: () => viewModel.changeMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final day in ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'])
              Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(fontSize: 12, color: NativaColors.gray),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ((offset + days + 6) ~/ 7) * 7,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 42,
          ),
          itemBuilder: (context, index) {
            final day = index - offset + 1;
            if (day < 1 || day > days) return const SizedBox.shrink();
            final event = events
                .where((delivery) => delivery.date.day == day)
                .firstOrNull;
            final isToday = today.year == month.year &&
                today.month == month.month &&
                today.day == day;
            return Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: event != null
                      ? (event.status == DeliveryStatus.completed
                          ? NativaColors.lightGreen
                          : NativaColors.yellow)
                      : (isToday
                          ? NativaColors.terracotta
                          : Colors.transparent),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontWeight: event != null || isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isToday && event == null
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    if (event != null)
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: NativaColors.green,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
