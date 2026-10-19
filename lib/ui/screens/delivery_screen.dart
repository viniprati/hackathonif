import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../theme.dart';
import '../view_models/delivery_view_model.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key, required this.viewModel});
  final DeliveryViewModel viewModel;

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  bool _showPendingOnly = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final deliveries = widget.viewModel.deliveries
              .where(
                (delivery) =>
                    !_showPendingOnly ||
                    delivery.status == DeliveryStatus.pending,
              )
              .toList();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Entregas',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Acompanhe os lotes e a distribuição para as escolas.',
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) =>
                          NewDeliveryDialog(viewModel: widget.viewModel),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Nova distribuição'),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      label: const Text('Somente pendentes'),
                      selected: _showPendingOnly,
                      onSelected: (value) =>
                          setState(() => _showPendingOnly = value),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (deliveries.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Nenhuma entrega nesta seleção.'),
                      ),
                    ),
                  ...deliveries.map(
                    (delivery) => Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DeliveryDetails(
                              viewModel: widget.viewModel,
                              deliveryId: delivery.id,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      delivery.product,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  _StatusTag(status: delivery.status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${formatDate(delivery.date)} • Lote #${delivery.id}',
                                style:
                                    const TextStyle(color: NativaColors.gray),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.school_outlined, size: 18),
                                  const SizedBox(width: 5),
                                  Text('${delivery.schoolCount} escolas'),
                                  const SizedBox(width: 18),
                                  const Icon(Icons.scale_outlined, size: 18),
                                  const SizedBox(width: 5),
                                  Text(formatKg(delivery.distributedKg)),
                                ],
                              ),
                            ],
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
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});
  final DeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    final done = status == DeliveryStatus.completed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: done ? NativaColors.lightGreen : const Color(0xFFFFEAD3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        done ? 'Concluído' : 'Pendente',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: done ? NativaColors.darkGreen : NativaColors.earth,
        ),
      ),
    );
  }
}

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
          return Scaffold(
            appBar: AppBar(title: Text('Lote #${delivery.id}')),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            delivery.product,
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _StatusTag(status: delivery.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Entrega prevista: ${formatDate(delivery.date)}'),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _Metric(
                          label: 'Recebido',
                          value: formatKg(delivery.availableKg),
                        ),
                        _Metric(
                          label: 'Solicitado',
                          value: formatKg(
                            delivery.allocations.fold<double>(
                              0,
                              (sum, item) => sum + item.requestedKg,
                            ),
                          ),
                        ),
                        _Metric(
                          label: 'Rateado',
                          value: formatKg(delivery.distributedKg),
                        ),
                        _Metric(
                          label: 'Saldo',
                          value: formatKg(
                            delivery.availableKg - delivery.distributedKg,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Rateio por escola',
                      style:
                          TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Proporcional à solicitação, arredondado a 0,1 kg.',
                      style: TextStyle(color: NativaColors.gray),
                    ),
                    const SizedBox(height: 12),
                    ...delivery.allocations.map(
                      (allocation) => Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.school_outlined,
                            color: NativaColors.green,
                          ),
                          title: Text(allocation.school),
                          subtitle: Text(
                            allocation.allocatedKg == 0
                                ? 'Sem alocação • solicitado: ${formatKg(allocation.requestedKg)}'
                                : 'Solicitado: ${formatKg(allocation.requestedKg)}',
                          ),
                          trailing: Text(
                            formatKg(allocation.allocatedKg),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => viewModel.setStatus(
                        delivery.id,
                        delivery.status == DeliveryStatus.pending
                            ? DeliveryStatus.completed
                            : DeliveryStatus.pending,
                      ),
                      icon: Icon(
                        delivery.status == DeliveryStatus.pending
                            ? Icons.check
                            : Icons.undo,
                      ),
                      label: Text(
                        delivery.status == DeliveryStatus.pending
                            ? 'Marcar como concluído'
                            : 'Voltar para pendente',
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

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NativaColors.lightGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(label),
          ],
        ),
      );
}

class NewDeliveryDialog extends StatefulWidget {
  const NewDeliveryDialog({super.key, required this.viewModel});
  final DeliveryViewModel viewModel;

  @override
  State<NewDeliveryDialog> createState() => _NewDeliveryDialogState();
}

class _NewDeliveryDialogState extends State<NewDeliveryDialog> {
  final _form = GlobalKey<FormState>();
  final _product = TextEditingController();
  final _stock = TextEditingController();
  final _bulk = TextEditingController();
  final _schools = [TextEditingController(), TextEditingController()];
  final _requests = [TextEditingController(), TextEditingController()];
  DateTime _date = DateTime.now();
  String? _bulkError;

  @override
  void dispose() {
    _product.dispose();
    _stock.dispose();
    _bulk.dispose();
    for (final controller in [..._schools, ..._requests]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _quantity(String? value) {
    final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
    return parsed?.isFinite == true ? parsed : null;
  }

  @override
  Widget build(BuildContext context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Nova distribuição',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                      'Informe o lote recebido e o pedido de cada escola.'),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _product,
                    decoration: const InputDecoration(labelText: 'Produto'),
                    validator: (value) => value?.trim().isNotEmpty == true
                        ? null
                        : 'Informe o produto.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _stock,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Quantidade recebida (kg)',
                    ),
                    validator: (value) => (_quantity(value) ?? 0) >= 0.1
                        ? null
                        : 'Informe ao menos 0,1 kg.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (selected != null) setState(() => _date = selected);
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('Data: ${formatDate(_date)}'),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Solicitações das escolas',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bulk,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Colar lista de escolas (opcional)',
                      hintText: 'Escola A; 20\nEscola B; 35,5',
                      helperText:
                          'Uma escola por linha: nome; pedido em kg. Ideal para muitas escolas.',
                      helperMaxLines: 2,
                      errorText: _bulkError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ou preencha manualmente:',
                    style: TextStyle(color: NativaColors.gray),
                  ),
                  const SizedBox(height: 8),
                  for (var index = 0; index < _schools.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _schools[index],
                              decoration: InputDecoration(
                                labelText: 'Escola ${index + 1}',
                              ),
                              validator: (value) =>
                                  _bulk.text.trim().isNotEmpty ||
                                          value?.trim().isNotEmpty == true
                                      ? null
                                      : 'Informe a escola.',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _requests[index],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Pedido (kg)',
                              ),
                              validator: (value) =>
                                  _bulk.text.trim().isNotEmpty ||
                                          (_quantity(value) ?? 0) >= 0.1
                                      ? null
                                      : 'Mín. 0,1',
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _schools.add(TextEditingController());
                      _requests.add(TextEditingController());
                    }),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar escola'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      if (!_form.currentState!.validate()) return;
                      final requests = <SchoolRequest>[];
                      if (_bulk.text.trim().isNotEmpty) {
                        for (final line in _bulk.text.trim().split('\n')) {
                          final separator = line.lastIndexOf(';');
                          if (separator < 1) {
                            setState(
                              () => _bulkError =
                                  'Use uma escola e um peso por linha, separados por ponto e vírgula.',
                            );
                            return;
                          }
                          final school = line.substring(0, separator).trim();
                          final quantity = _quantity(
                            line.substring(separator + 1).trim(),
                          );
                          if (school.isEmpty ||
                              quantity == null ||
                              quantity < 0.1) {
                            setState(
                              () => _bulkError =
                                  'Revise nomes e pesos: cada pedido deve ter ao menos 0,1 kg.',
                            );
                            return;
                          }
                          requests.add(
                            SchoolRequest(
                                school: school, requestedKg: quantity),
                          );
                        }
                      } else {
                        for (var index = 0; index < _schools.length; index++) {
                          requests.add(
                            SchoolRequest(
                              school: _schools[index].text.trim(),
                              requestedKg: _quantity(_requests[index].text)!,
                            ),
                          );
                        }
                      }
                      setState(() => _bulkError = null);
                      widget.viewModel.addDelivery(
                        product: _product.text.trim(),
                        availableKg: _quantity(_stock.text)!,
                        date: _date,
                        requests: requests,
                      );
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.of(context).pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Distribuição calculada e cadastrada.'),
                        ),
                      );
                    },
                    child: const Text('Calcular e cadastrar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
