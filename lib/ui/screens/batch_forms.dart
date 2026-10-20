import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/catalog.dart';
import '../theme.dart';
import '../view_models/delivery_view_model.dart';

double? _parseKg(String? value) {
  final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
  return parsed?.isFinite == true ? parsed : null;
}

bool _validKg(double? quantity) =>
    quantity != null &&
    quantity >= 0 &&
    quantity <= 1000000 &&
    (quantity * 10).isFinite &&
    (quantity * 10 - (quantity * 10).round()).abs() < 1e-7;

int? _parsePrice(String value) {
  if (!RegExp(r'^\d+([,.]\d{1,2})?$').hasMatch(value.trim())) return null;
  final parts = value.trim().replaceAll(',', '.').split('.');
  final price = int.tryParse(
      '${parts[0]}${parts.length == 1 ? '00' : parts[1].padRight(2, '0')}');
  return price != null && price <= 1000000 ? price : null;
}

class _ItemInputs {
  String? food;
  final quantity = TextEditingController();
  final price = TextEditingController();
  void dispose() {
    quantity.dispose();
    price.dispose();
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
  final _participatingSchools = <String>{};
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _name.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _selectFood(_ItemInputs item, String? food) {
    item.food = food;
    final price = food == null ? null : findFood(food)?.priceCents;
    item.price.text = price == null
        ? ''
        : (price / 100).toStringAsFixed(2).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final allowedFoods =
        widget.viewModel.foods.map((food) => food.name).toList();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Cadastrar montante',
                      style:
                          TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _name,
                      maxLength: 120,
                      decoration:
                          const InputDecoration(labelText: 'Nome do montante'),
                      validator: (value) => value?.trim().isNotEmpty == true
                          ? null
                          : 'Informe o nome.'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100));
                      if (date != null && mounted) setState(() => _date = date);
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('Data: ${formatDate(_date)}'),
                  ),
                  const SizedBox(height: 12),
                  FormField<List<String>>(
                    initialValue: const [],
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Selecione pelo menos uma escola participante.'
                        : null,
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Escolas participantes',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text(
                            'Selecione as escolas que participarão deste montante. A escolha vale para todos os alimentos.'),
                        Text(
                            '${_participatingSchools.length} ${_participatingSchools.length == 1 ? 'escola selecionada' : 'escolas selecionadas'}'),
                        for (final school in widget.viewModel.knownSchools)
                          CheckboxListTile(
                            key: ValueKey('batch-school-$school'),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(school),
                            value: _participatingSchools.contains(school),
                            onChanged: (selected) => setState(() {
                              if (selected == true) {
                                _participatingSchools.add(school);
                              } else {
                                _participatingSchools.remove(school);
                              }
                              field.didChange(_participatingSchools.toList());
                            }),
                          ),
                        Wrap(children: [
                          TextButton(
                              onPressed: () => setState(() {
                                    _participatingSchools
                                        .addAll(widget.viewModel.knownSchools);
                                    field.didChange(
                                        _participatingSchools.toList());
                                  }),
                              child: const Text('Selecionar todas')),
                          TextButton(
                              onPressed: () => setState(() {
                                    _participatingSchools.clear();
                                    field.didChange(const []);
                                  }),
                              child: const Text('Limpar seleção')),
                        ]),
                        if (field.hasError)
                          Semantics(
                              liveRegion: true,
                              child: Text(field.errorText!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                      'Selecione alimentos do catálogo e confirme o preço por kg. Deixe o preço em branco se desconhecido.',
                      style: TextStyle(fontSize: 12, color: NativaColors.gray)),
                  const SizedBox(height: 10),
                  for (var index = 0; index < _items.length; index++)
                    Card(
                        key: ObjectKey(_items[index]),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(children: [
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                  '${identityHashCode(_items[index])}-${_items[index].food}'),
                              initialValue: _items[index].food,
                              isExpanded: true,
                              decoration: InputDecoration(
                                  labelText: 'Alimento ${index + 1}'),
                              items: [
                                for (final food in allowedFoods)
                                  DropdownMenuItem(
                                      value: food,
                                      child: Text(food,
                                          overflow: TextOverflow.ellipsis))
                              ],
                              onChanged: (value) => setState(
                                  () => _selectFood(_items[index], value)),
                              validator: (value) => value == null
                                  ? 'Escolha um alimento cadastrado.'
                                  : _items
                                              .where(
                                                  (item) => item.food == value)
                                              .length >
                                          1
                                      ? 'Alimento repetido no montante.'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      child: TextFormField(
                                    controller: _items[index].quantity,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration:
                                        const InputDecoration(labelText: 'Kg'),
                                    validator: (value) =>
                                        _validKg(_parseKg(value)) &&
                                                (_parseKg(value) ?? 0) >= 0.1
                                            ? null
                                            : 'Use entre 0,1 e 1.000.000 kg.',
                                  )),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: TextFormField(
                                    controller: _items[index].price,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                        labelText: 'R\$ / kg'),
                                    validator: (value) =>
                                        value?.trim().isEmpty == true ||
                                                _parsePrice(value ?? '') != null
                                            ? null
                                            : 'Preço inválido.',
                                  )),
                                  if (_items.length > 1)
                                    IconButton(
                                        tooltip: 'Remover alimento',
                                        icon: const Icon(Icons.close),
                                        onPressed: () {
                                          final removed =
                                              _items.removeAt(index);
                                          setState(() {});
                                          WidgetsBinding.instance
                                              .addPostFrameCallback(
                                                  (_) => removed.dispose());
                                        }),
                                ]),
                          ]),
                        )),
                  TextButton.icon(
                      onPressed: () =>
                          setState(() => _items.add(_ItemInputs())),
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar alimento')),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: () {
                        if (!_form.currentState!.validate()) return;
                        try {
                          widget.viewModel.addBatch(
                              name: _name.text.trim(),
                              date: _date,
                              participatingSchools:
                                  _participatingSchools.toList(),
                              items: [
                                for (final item in _items)
                                  BatchItem(
                                      product: item.food!,
                                      availableKg:
                                          _parseKg(item.quantity.text)!,
                                      unitPriceCents:
                                          _parsePrice(item.price.text)),
                              ]);
                          Navigator.of(context).pop();
                        } on ArgumentError catch (error) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${error.message}')));
                        }
                      },
                      child: const Text('Salvar montante')),
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar')),
                ],
              )),
        ),
      ),
    );
  }
}

class AllocationScreen extends StatefulWidget {
  const AllocationScreen(
      {super.key, required this.viewModel, required this.deliveryId});
  final DeliveryViewModel viewModel;
  final int deliveryId;
  @override
  State<AllocationScreen> createState() => _AllocationScreenState();
}

class _AllocationScreenState extends State<AllocationScreen> {
  final _form = GlobalKey<FormState>();
  final _quantities = <String, TextEditingController>{};
  late final Delivery _delivery;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _delivery = widget.viewModel.deliveries
        .firstWhere((item) => item.id == widget.deliveryId);
    for (final school in widget.viewModel.schoolsForDelivery(_delivery)) {
      final requested = _delivery.allocations
          .where((item) => item.school == school)
          .fold<double>(0, (sum, item) => sum + item.requestedKg);
      _quantities[school] = TextEditingController(
          text: requested > 0
              ? requested.toStringAsFixed(1).replaceAll('.', ',')
              : '');
    }
  }

  @override
  void dispose() {
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<SchoolRequest> get _requests => [
        for (final entry in _quantities.entries)
          SchoolRequest(
              school: entry.key,
              requestedKg: (_parseKg(entry.value.text) ?? 0)
                  .clamp(0, double.infinity)
                  .toDouble()),
      ];

  @override
  Widget build(BuildContext context) {
    final preview = widget.viewModel.previewRequests(_delivery.id, _requests);
    return Scaffold(
      appBar: AppBar(title: Text(_delivery.product)),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('${_delivery.product} • ${_delivery.batchName}',
              style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: NativaColors.darkGreen)),
          Text('Recebido: ${formatKg(_delivery.availableKg)}'),
          const SizedBox(height: 18),
          const Text('Pedidos das escolas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text(
              'Somente as escolas participantes deste montante aparecem aqui. Deixe em branco quando não houver pedido deste alimento. A soma não pode ultrapassar o recebido.',
              style: TextStyle(color: NativaColors.gray)),
          const SizedBox(height: 12),
          Form(
              key: _form,
              child: Column(children: [
                for (final entry in _quantities.entries)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Expanded(
                                child: Text(entry.key,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                            const SizedBox(width: 12),
                            SizedBox(
                                width: 125,
                                child: TextFormField(
                                  key: Key('school-quantity-${entry.key}'),
                                  controller: entry.value,
                                  enabled: !_confirmed,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                      labelText: 'Pedido (kg)',
                                      errorMaxLines: 3),
                                  onChanged: (_) => setState(() {}),
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  validator: (value) {
                                    if (value?.trim().isNotEmpty == true &&
                                        !_validKg(_parseKg(value))) {
                                      return 'Use 0,1 kg.';
                                    }
                                    if (preview.requestedKg >
                                        _delivery.availableKg + 1e-7) {
                                      return 'Soma acima do recebido';
                                    }
                                    return null;
                                  },
                                )),
                          ]))),
              ])),
          const SizedBox(height: 12),
          Card(
              color: NativaColors.lightGreen,
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total pedido: ${formatKg(preview.requestedKg)}'),
                        Text(
                            'Disponível para os pedidos: ${formatKg((preview.receivedKg - preview.requestedKg).clamp(0, preview.receivedKg).toDouble())}'),
                        if (preview.shortageKg > 1e-7)
                          Text(
                              'Limite excedido em ${formatKg(preview.shortageKg)}. Reduza os pedidos antes de salvar.'),
                        if (preview.remainderKg > 1e-7 &&
                            preview.shortageKg <= 1e-7)
                          Text(
                              'Saldo: ${formatKg(preview.remainderKg)}. Confirme e informe se houve sobra ou perda.'),
                      ]))),
          const SizedBox(height: 12),
          if (!_confirmed)
            FilledButton.icon(
                onPressed: _confirmSave,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar rateio'))
          else ...[
            FilledButton.icon(
                onPressed: () async {
                  final loss = await showDialog<double>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => _ClassifyBalanceDialog(
                          remainderKg: preview.remainderKg));
                  if (loss != null && mounted) _persist(loss);
                },
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Informar sobra ou perda')),
            TextButton(
                onPressed: () => setState(() => _confirmed = false),
                child: const Text('Revisar pedidos')),
          ],
        ]),
      )),
    );
  }

  Future<void> _confirmSave() async {
    if (!_form.currentState!.validate()) return;
    final preview = widget.viewModel.previewRequests(_delivery.id, _requests);
    if (preview.remainderKg <= 1e-7) {
      _persist(0);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Confirmar saldo de alimento'),
            content: Text(
                'Restam ${formatKg(preview.remainderKg)} de ${_delivery.product}. Deseja prosseguir? Em seguida, classifique o saldo como sobra aproveitável ou perda.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Confirmar')),
            ],
          )),
    );
    if (confirmed == true && mounted) setState(() => _confirmed = true);
  }

  void _persist(double loss) {
    try {
      widget.viewModel.saveRequests(_delivery.id, _requests,
          remainderConfirmed: _confirmed, lossKg: loss);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
          const SnackBar(content: Text('Rateio e classificação salvos.')));
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${error.message}')));
    }
  }
}

class _ClassifyBalanceDialog extends StatefulWidget {
  const _ClassifyBalanceDialog({required this.remainderKg});
  final double remainderKg;
  @override
  State<_ClassifyBalanceDialog> createState() => _ClassifyBalanceDialogState();
}

class _ClassifyBalanceDialogState extends State<_ClassifyBalanceDialog> {
  final _form = GlobalKey<FormState>();
  final _loss = TextEditingController();
  String? _kind;
  @override
  void dispose() {
    _loss.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Classificar saldo'),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Saldo: ${formatKg(widget.remainderKg)}'),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Destino do saldo'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'surplus',
                                  child: Text('Sobra aproveitável')),
                              DropdownMenuItem(
                                  value: 'loss', child: Text('Houve perda'))
                            ],
                            onChanged: (value) => setState(() {
                              _kind = value;
                              _loss.text = widget.remainderKg
                                  .toStringAsFixed(1)
                                  .replaceAll('.', ',');
                            }),
                            validator: (value) => value == null
                                ? 'Escolha uma classificação.'
                                : null,
                          ),
                          if (_kind == 'loss') ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _loss,
                              decoration: const InputDecoration(
                                  labelText: 'Quantidade perdida (kg)'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: (value) => _validKg(_parseKg(value)) &&
                                      (_parseKg(value) ?? 0) > 0 &&
                                      _parseKg(value)! <=
                                          widget.remainderKg + 1e-7
                                  ? null
                                  : 'Informe até ${formatKg(widget.remainderKg)}.',
                            ),
                            const SizedBox(height: 8),
                            const Text(
                                'O restante será registrado como sobra aproveitável.'),
                          ],
                        ])))),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.of(context)
                      .pop(_kind == 'loss' ? _parseKg(_loss.text)! : 0.0);
                }
              },
              child: const Text('Salvar classificação')),
        ],
      ));
}
