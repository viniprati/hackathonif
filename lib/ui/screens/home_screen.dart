import 'package:flutter/material.dart';

import '../../domain/batch_summary.dart';
import '../theme.dart';
import '../view_models/delivery_view_model.dart';
import 'batch_forms.dart';
import 'batch_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.viewModel,
    required this.openBatches,
  });

  final DeliveryViewModel viewModel;
  final VoidCallback openBatches;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final batches = widget.viewModel.batches;
          final pending = batches.where((batch) => !batch.isCompleted).toList();
          final selected = _selectedDate == null
              ? pending
              : pending
                  .where(
                      (batch) => DateUtils.isSameDay(batch.date, _selectedDate))
                  .toList();
          final completed =
              batches.where((batch) => batch.isCompleted).toList();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final mainContent = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (batches.isEmpty && widget.viewModel.sync != null)
                        const Card(
                            child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                    'Para buscar os dados compartilhados, abra Perfil e toque em Sincronizar dados.'))),
                      _CalendarCard(
                        viewModel: widget.viewModel,
                        batches: batches,
                        selectedDate: _selectedDate,
                        onSelect: (date) => setState(() {
                          _selectedDate =
                              DateUtils.isSameDay(date, _selectedDate)
                                  ? null
                                  : date;
                        }),
                        onChangeMonth: (offset) {
                          setState(() => _selectedDate = null);
                          widget.viewModel.changeMonth(offset);
                        },
                      ),
                      const SizedBox(height: 14),
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
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'MONTANTES PENDENTES',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: NativaColors.darkGreen,
                              ),
                            ),
                          ),
                          if (_selectedDate != null)
                            TextButton(
                              onPressed: () =>
                                  setState(() => _selectedDate = null),
                              child: const Text('Ver todos'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (selected.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child:
                                Text('Nenhum montante pendente nesta seleção.'),
                          ),
                        ),
                      for (final batch in selected.take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: BatchCard(
                            batch: batch,
                            onTap: () => _openBatch(context, batch.id),
                          ),
                        ),
                      TextButton.icon(
                        onPressed: widget.openBatches,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Ver todos os montantes'),
                      ),
                      if (completed.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'HISTÓRICO RECENTE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: NativaColors.darkGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        BatchCard(
                          batch: completed.first,
                          onTap: () => _openBatch(context, completed.first.id),
                        ),
                      ],
                    ],
                  );

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ASSOCIAÇÃO APROVISTA',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: NativaColors.earth,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Olá, Seu José!',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: NativaColors.darkGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Image.asset(
                            'assets/images/nativa_logo.png',
                            width: 44,
                            height: 44,
                            semanticLabel: 'Logo Nativa',
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Card(
                        color: NativaColors.lightGreen,
                        child: ListTile(
                          onTap: widget.openBatches,
                          leading: const Icon(
                            Icons.event_note_outlined,
                            color: NativaColors.darkGreen,
                          ),
                          title: Text(
                            '${widget.viewModel.pendingCount} entregas pendentes',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${widget.viewModel.pendingBatchCount} montantes aguardando divisão',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                      const SizedBox(height: 16),
                      mainContent,
                    ],
                  );
                },
              ),
            ),
          );
        },
      );

  void _openBatch(BuildContext context, int id) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BatchDetailsScreen(
            viewModel: widget.viewModel,
            batchId: id,
          ),
        ),
      );
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.viewModel,
    required this.batches,
    required this.selectedDate,
    required this.onSelect,
    required this.onChangeMonth,
  });

  final DeliveryViewModel viewModel;
  final List<BatchSummary> batches;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<int> onChangeMonth;

  @override
  Widget build(BuildContext context) {
    final month = viewModel.selectedMonth;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = DateTime(month.year, month.month).weekday - 1;
    final title = monthNames[month.month - 1];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Mês anterior',
                  onPressed: () => onChangeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${title[0].toUpperCase()}${title.substring(1)} ${month.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Próximo mês',
                  onPressed: () => onChangeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: [
                for (final label in [
                  'Seg',
                  'Ter',
                  'Qua',
                  'Qui',
                  'Sex',
                  'Sáb',
                  'Dom'
                ])
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: NativaColors.gray,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ((offset + days + 6) ~/ 7) * 7,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 27 + MediaQuery.textScalerOf(context).scale(16),
              ),
              itemBuilder: (context, index) {
                final day = index - offset + 1;
                if (day < 1 || day > days) return const SizedBox.shrink();
                final date = DateTime(month.year, month.month, day);
                final events = batches.where(
                  (batch) => DateUtils.isSameDay(batch.date, date),
                );
                final isSelected = DateUtils.isSameDay(date, selectedDate);
                final isToday = DateUtils.isSameDay(date, DateTime.now());
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: '$day de $title, ${events.length} montantes',
                  child: InkWell(
                    onTap: () => onSelect(date),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? NativaColors.yellow.withValues(alpha: 0.35)
                            : null,
                        border: isToday
                            ? Border.all(color: NativaColors.earth)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontWeight: isSelected || isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (events.isNotEmpty)
                            Icon(
                              Icons.circle,
                              size: 7,
                              color: events.every((batch) => batch.isCompleted)
                                  ? NativaColors.green
                                  : NativaColors.yellow,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
