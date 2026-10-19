import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../theme.dart';
import '../view_models/delivery_view_model.dart';
import 'delivery_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.viewModel,
    required this.openDeliveries,
    required this.openDocuments,
  });

  final DeliveryViewModel viewModel;
  final VoidCallback openDeliveries;
  final VoidCallback openDocuments;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final month = widget.viewModel.selectedMonth;
          final deliveries = widget.viewModel.deliveries
              .where((delivery) =>
                  delivery.date.year == month.year &&
                  delivery.date.month == month.month &&
                  (_selectedDate == null ||
                      DateUtils.isSameDay(delivery.date, _selectedDate)))
              .toList()
            ..sort((a, b) {
              if (a.status != b.status) {
                return a.status == DeliveryStatus.pending ? -1 : 1;
              }
              return a.date.compareTo(b.date);
            });

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                children: [
                  const _HomeHeader(),
                  const SizedBox(height: 16),
                  _CalendarCard(
                    viewModel: widget.viewModel,
                    selectedDate: _selectedDate,
                    onDateSelected: (date) => setState(() {
                      _selectedDate = DateUtils.isSameDay(_selectedDate, date)
                          ? null
                          : date;
                    }),
                    onMonthChanged: (offset) {
                      setState(() => _selectedDate = null);
                      widget.viewModel.changeMonth(offset);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    const Expanded(
                        child: Text('PAINEL DE ATIVIDADES',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: NativaColors.darkGreen))),
                    if (_selectedDate != null)
                      TextButton(
                          onPressed: () => setState(() => _selectedDate = null),
                          child: const Text('Ver todo o mês')),
                  ]),
                  const SizedBox(height: 8),
                  if (deliveries.isEmpty)
                    Card(
                        child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(_selectedDate == null
                          ? 'Nenhuma entrega prevista neste mês.'
                          : 'Nenhuma entrega prevista para este dia.'),
                    )),
                  for (final delivery in deliveries.take(3))
                    _ActivityCard(
                      delivery: delivery,
                      onOpen: () =>
                          Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => DeliveryDetails(
                            viewModel: widget.viewModel,
                            deliveryId: delivery.id),
                      )),
                    ),
                  if (deliveries.length > 3)
                    TextButton.icon(
                      onPressed: widget.openDeliveries,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text('Ver todas as ${deliveries.length} entregas'),
                    ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: _ShortcutCard(
                            icon: Icons.local_shipping_outlined,
                            label: 'ENTREGAS A FAZER',
                            onTap: widget.openDeliveries)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _ShortcutCard(
                            icon: Icons.inventory_2_outlined,
                            label: 'CONTROLE DE LOTES',
                            onTap: widget.openDocuments)),
                  ]),
                  const SizedBox(height: 14),
                  Text(
                    '${widget.viewModel.pendingCount} entregas pendentes  •  ${formatKg(widget.viewModel.totalDistributedKg)} rateados',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 12, color: NativaColors.gray),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    const weekdays = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo'
    ];
    return Row(children: [
      Expanded(
          child: Text('${weekdays[today.weekday - 1]}, ${today.day}',
              style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: NativaColors.earth))),
      Image.asset('assets/images/nativa_logo.png',
          width: 29, height: 29, semanticLabel: 'Logo Nativa'),
      const SizedBox(width: 5),
      const Text('Nativa',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard(
      {required this.viewModel,
      required this.selectedDate,
      required this.onDateSelected,
      required this.onMonthChanged});

  final DeliveryViewModel viewModel;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<int> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final month = viewModel.selectedMonth;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = DateTime(month.year, month.month).weekday - 1;
    final events = viewModel.deliveries
        .where((delivery) =>
            delivery.date.year == month.year &&
            delivery.date.month == month.month)
        .toList();
    final today = DateTime.now();
    final monthName = monthNames[month.month - 1];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        child: Column(children: [
          Row(children: [
            IconButton(
                tooltip: 'Mês anterior',
                onPressed: () => onMonthChanged(-1),
                icon: const Icon(Icons.chevron_left)),
            Expanded(
                child: Text(
                    '${monthName[0].toUpperCase()}${monthName.substring(1)} ${month.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700))),
            IconButton(
                tooltip: 'Próximo mês',
                onPressed: () => onMonthChanged(1),
                icon: const Icon(Icons.chevron_right)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            for (final day in ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'])
              Expanded(
                  child: Text(day,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11, color: NativaColors.gray))),
          ]),
          const SizedBox(height: 5),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ((offset + days + 6) ~/ 7) * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, mainAxisExtent: 47),
            itemBuilder: (context, index) {
              final day = index - offset + 1;
              if (day < 1 || day > days) return const SizedBox.shrink();
              final date = DateTime(month.year, month.month, day);
              final dayEvents = events
                  .where((delivery) => delivery.date.day == day)
                  .take(3)
                  .toList();
              final selected = DateUtils.isSameDay(date, selectedDate);
              final isToday = DateUtils.isSameDay(date, today);
              return Semantics(
                button: true,
                selected: selected,
                label: '$day de $monthName, ${dayEvents.length} entregas',
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => onDateSelected(date),
                  child: Center(
                      child: Container(
                    width: 39,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: selected
                          ? NativaColors.yellow.withValues(alpha: 0.35)
                          : Colors.transparent,
                      border: isToday
                          ? Border.all(color: NativaColors.earth)
                          : null,
                    ),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$day',
                              style: TextStyle(
                                  fontWeight: selected || isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                          if (dayEvents.isNotEmpty)
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final delivery in dayEvents)
                                    _CalendarMarker(delivery: delivery),
                                ]),
                        ]),
                  )),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }
}

class _CalendarMarker extends StatelessWidget {
  const _CalendarMarker({required this.delivery});
  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final completed = delivery.status == DeliveryStatus.completed;
    final late = !completed &&
        DateUtils.dateOnly(delivery.date)
            .isBefore(DateUtils.dateOnly(DateTime.now()));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Icon(
        completed
            ? Icons.check_circle
            : late
                ? Icons.error
                : Icons.circle,
        size: completed || late ? 10 : 8,
        color: completed
            ? NativaColors.green
            : late
                ? NativaColors.terracotta
                : NativaColors.yellow,
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.delivery, required this.onOpen});
  final Delivery delivery;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final completed = delivery.status == DeliveryStatus.completed;
    final late = !completed &&
        DateUtils.dateOnly(delivery.date)
            .isBefore(DateUtils.dateOnly(DateTime.now()));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: completed ? NativaColors.lightGreen : Colors.white,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Text(delivery.product,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700))),
              _ActivityBadge(
                text: completed
                    ? 'ENTREGUE'
                    : late
                        ? 'ATRASADA'
                        : 'PENDENTE',
                color: completed
                    ? NativaColors.green
                    : late
                        ? NativaColors.terracotta
                        : NativaColors.yellow,
                lightText: completed || late,
              ),
            ]),
            const SizedBox(height: 8),
            _ActivityDetail(
                icon: Icons.school_outlined,
                text: 'Destino: ${delivery.schoolCount} escolas'),
            const SizedBox(height: 4),
            _ActivityDetail(
                icon: Icons.schedule_outlined,
                text:
                    '${completed ? 'Concluída' : 'Prevista'} em ${formatDate(delivery.date)}'),
            const SizedBox(height: 8),
            Row(children: [
              Text(formatKg(delivery.distributedKg),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: NativaColors.darkGreen)),
              const Spacer(),
              const Text('Ver detalhes',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const Icon(Icons.chevron_right, size: 18),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge(
      {required this.text, required this.color, required this.lightText});
  final String text;
  final Color color;
  final bool lightText;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(16)),
        child: Text(text,
            style: TextStyle(
                color: lightText ? Colors.white : Colors.black87,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );
}

class _ActivityDetail extends StatelessWidget {
  const _ActivityDetail({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 15, color: NativaColors.gray),
        const SizedBox(width: 5),
        Flexible(child: Text(text, style: const TextStyle(fontSize: 12))),
      ]);
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 112,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: NativaColors.earth, size: 27),
                    const SizedBox(height: 8),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ]),
            ),
          ),
        ),
      );
}
