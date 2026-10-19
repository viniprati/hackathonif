import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../theme.dart';
import '../view_models/delivery_view_model.dart';

double? _parseKg(String? value) {
  final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
  return parsed?.isFinite == true ? parsed : null;
}

class _ItemInputs {
  _ItemInputs()
      : product = TextEditingController(),
        quantity = TextEditingController();

  final TextEditingController product;
  final TextEditingController quantity;

  void dispose() {
    product.dispose();
    quantity.dispose();
  }
}

class NewBatchDialog extends StatefulWidget {
  const NewBatchDialog({super.key, required this.viewModel});

  final DeliveryViewModel viewModel;

  @override
  State<NewBatchDialog> createState() => _NewBatchDialogState();
}

class _NewBatchDialogState extends State<NewBatchDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _items = [_ItemInputs()];
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _name.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Cadastrar montante',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                      'Dê um nome ao montante e informe os alimentos recebidos.'),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _name,
                    decoration:
                        const InputDecoration(labelText: 'Nome do montante'),
                    validator: (value) => value?.trim().isNotEmpty == true
                        ? null
                        : 'Informe o nome do montante.',
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
                  const Text('Alimentos',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (var index = 0; index < _items.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _items[index].product,
                              decoration: InputDecoration(
                                labelText: 'Alimento ${index + 1}',
                              ),
                              validator: (value) =>
                                  value?.trim().isNotEmpty == true
                                      ? null
                                      : 'Informe o alimento.',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _items[index].quantity,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration:
                                  const InputDecoration(labelText: 'Kg'),
                              validator: (value) =>
                                  (_parseKg(value) ?? 0) >= 0.1
                                      ? null
                                      : 'Mín. 0,1',
                            ),
                          ),
                          if (_items.length > 1)
                            IconButton(
                              tooltip: 'Remover alimento',
                              onPressed: () {
                                final removed = _items.removeAt(index);
                                setState(() {});
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => removed.dispose(),
                                );
                              },
                              icon: const Icon(Icons.close),
                            ),
                        ],
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => setState(() => _items.add(_ItemInputs())),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar alimento'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      if (!_form.currentState!.validate()) return;
                      widget.viewModel.addBatch(
                        name: _name.text.trim(),
                        date: _date,
                        items: [
                          for (final item in _items)
                            BatchItem(
                              product: item.product.text.trim(),
                              availableKg: _parseKg(item.quantity.text)!,
                            ),
                        ],
                      );
                      Navigator.of(context).pop();
                    },
                    child: const Text('Salvar montante'),
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

class _SchoolInputs {
  _SchoolInputs(String school, double requestedKg)
      : name = TextEditingController(text: school),
        quantity = TextEditingController(
          text: requestedKg > 0 ? requestedKg.toStringAsFixed(1) : '',
        );

  final TextEditingController name;
  final TextEditingController quantity;

  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}

class AllocationScreen extends StatefulWidget {
  const AllocationScreen({
    super.key,
    required this.viewModel,
    required this.deliveryId,
  });

  final DeliveryViewModel viewModel;
  final int deliveryId;

  @override
  State<AllocationScreen> createState() => _AllocationScreenState();
}

class _AllocationScreenState extends State<AllocationScreen> {
  final _form = GlobalKey<FormState>();
  final _schools = <_SchoolInputs>[];
  late final Delivery _delivery;

  @override
  void initState() {
    super.initState();
    _delivery = widget.viewModel.deliveries.firstWhere(
      (item) => item.id == widget.deliveryId,
    );
    if (_delivery.allocations.isNotEmpty) {
      for (final allocation in _delivery.allocations) {
        _schools.add(_SchoolInputs(allocation.school, allocation.requestedKg));
      }
    } else {
      for (final school in widget.viewModel.knownSchools) {
        _schools.add(_SchoolInputs(school, 0));
      }
    }
    if (_schools.isEmpty) _schools.add(_SchoolInputs('', 0));
  }

  @override
  void dispose() {
    for (final school in _schools) {
      school.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requested = _schools.fold<double>(
      0,
      (sum, school) => sum + (_parseKg(school.quantity.text) ?? 0),
    );
    final difference = _delivery.availableKg - requested;
    final balanceMessage = difference > 0.05
        ? 'Sobram ${formatKg(difference)} deste alimento.'
        : difference < -0.05
            ? 'Faltam ${formatKg(-difference)}. O estoque será rateado proporcionalmente.'
            : 'Pedido e quantidade recebida estão equilibrados.';

    return Scaffold(
      appBar: AppBar(title: Text(_delivery.product)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${_delivery.product} • ${_delivery.batchName}',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: NativaColors.darkGreen,
                ),
              ),
              const SizedBox(height: 6),
              Text('Recebido: ${formatKg(_delivery.availableKg)}'),
              const SizedBox(height: 18),
              const Text(
                'Pedidos das escolas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Informe o pedido em kg. Se faltar alimento, o app calcula o rateio proporcional.',
                style: TextStyle(color: NativaColors.gray),
              ),
              const SizedBox(height: 12),
              Form(
                key: _form,
                child: Column(
                  children: [
                    for (var index = 0; index < _schools.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _schools[index].name,
                                decoration: InputDecoration(
                                  labelText: 'Escola ${index + 1}',
                                ),
                                validator: (value) =>
                                    value?.trim().isNotEmpty == true
                                        ? null
                                        : 'Informe a escola.',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _schools[index].quantity,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Pedido (kg)',
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (value) {
                                  final quantity = value?.trim().isEmpty == true
                                      ? 0.0
                                      : _parseKg(value);
                                  return quantity != null &&
                                          (quantity == 0 || quantity >= 0.1)
                                      ? null
                                      : 'Peso inválido';
                                },
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remover escola',
                              onPressed: () {
                                final removed = _schools.removeAt(index);
                                setState(() {});
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => removed.dispose(),
                                );
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _schools.add(_SchoolInputs('', 0));
                }),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar escola'),
              ),
              const SizedBox(height: 16),
              Card(
                color: difference < -0.05
                    ? const Color(0xFFFFEAD3)
                    : NativaColors.lightGreen,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        balanceMessage,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Total pedido: ${formatKg(requested)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar rateio'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final requests = [
      for (final school in _schools)
        SchoolRequest(
          school: school.name.text.trim(),
          requestedKg: _parseKg(school.quantity.text) ?? 0,
        ),
    ];
    try {
      widget.viewModel.saveRequests(_delivery.id, requests);
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.message?.toString() ?? 'Revise os pedidos.')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Rateio salvo e alimento finalizado.')),
    );
  }
}
