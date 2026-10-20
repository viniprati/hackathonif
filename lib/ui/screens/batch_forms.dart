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
  final foodFocus = FocusNode();
  final quantity = TextEditingController();
  final price = TextEditingController();
  void dispose() {
    foodFocus.dispose();
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
  final _removed = <(_ItemInputs, int)>[];
  final _participatingSchools = <String>{};
  final _schoolFocus = FocusNode();
  final _undoFocus = FocusNode();
  final _undoKey = GlobalKey();
  Set<String>? _priorSchools;
  DateTime _date = DateTime.now();
  bool _saving = false, _closing = false;
  int? _createdBatchId;
  String? _error;
  bool get _editable => !_saving && _createdBatchId == null;
  bool get _dirty =>
      _name.text.isNotEmpty ||
      _participatingSchools.isNotEmpty ||
      _items.length > 1 ||
      _removed.isNotEmpty ||
      !DateUtils.isSameDay(_date, DateTime.now()) ||
      _items.any((item) =>
          item.food != null ||
          item.quantity.text.isNotEmpty ||
          item.price.text.isNotEmpty);

  @override
  void dispose() {
    _name.dispose();
    _schoolFocus.dispose();
    _undoFocus.dispose();
    for (final item in {..._items, ..._removed.map((entry) => entry.$1)}) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _close() async {
    if (_saving || _closing) return;
    _closing = true;
    final accepted = !_dirty ||
        await confirmDiscard(context,
            title: _createdBatchId == null
                ? 'Descartar cadastro do montante?'
                : 'Fechar cadastro pendente?',
            consequence: _createdBatchId == null
                ? 'O cadastro de ${_name.text.trim().isEmpty ? 'este montante' : _name.text.trim()} ainda não foi salvo. Ao descartar, os alimentos, quantidades e escolas preenchidos serão perdidos.'
                : 'O montante ${_name.text.trim()} já está na cópia de trabalho, mas a gravação no aparelho não foi concluída. Fechar esta tela não o exclui. Mantenha o app aberto e tente salvar ou sincronizar antes de sair.',
            action: _createdBatchId == null
                ? 'Descartar cadastro'
                : 'Fechar cadastro');
    if (accepted && mounted) Navigator.pop(context);
    _closing = false;
  }

  void _remove(_ItemInputs item, int index) {
    if (!_editable || !_items.contains(item) || _items.length <= 1) return;
    setState(() {
      _items.remove(item);
      _removed.add((item, index));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _undoFocus.requestFocus();
      if (_undoKey.currentContext case final target?) {
        Scrollable.ensureVisible(target,
            duration: const Duration(milliseconds: 250));
      }
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_createdBatchId == null && !validateAccessibleForm(_form)) {
      setState(() => _error =
          'Confira os campos indicados abaixo. Seus valores foram mantidos.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      _createdBatchId ??= widget.viewModel.addBatch(
          name: _name.text.trim(),
          date: _date,
          participatingSchools: _participatingSchools.toList(),
          items: [
            for (final item in _items)
              BatchItem(
                  product: item.food!,
                  availableKg: _parseKg(item.quantity.text)!,
                  unitPriceCents: _parsePrice(item.price.text))
          ]);
      await widget.viewModel.sync?.persist();
      if (mounted) Navigator.pop(context);
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(() =>
            _error = '${error.message} Revise os campos e tente novamente.');
      }
    } on StateError {
      if (mounted) {
        setState(() => _error = _createdBatchId != null
            ? 'Não conseguimos gravar no aparelho. Mantenha o app aberto e toque em Tentar salvar no aparelho.'
            : 'Há uma sincronização em andamento. Aguarde e tente salvar novamente.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Não conseguimos gravar no aparelho. O montante continua na cópia de trabalho, sem duplicação. Mantenha o app aberto, confira o espaço disponível e toque em Tentar salvar no aparelho.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Dialog(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(20),
                  child: FocusTraversalGroup(
                      child: Form(
                          key: _form,
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Semantics(
                                    header: true,
                                    child: const Text('Cadastrar montante',
                                        style: TextStyle(
                                            fontSize: 23,
                                            fontWeight: FontWeight.bold))),
                                const SizedBox(height: 12),
                                const Text(
                                    'Os campos identificados como obrigatórios precisam ser preenchidos.'),
                                if (_error != null) GuidanceMessage(_error!),
                                TextFormField(
                                    controller: _name,
                                    enabled: _editable,
                                    maxLength: 120,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                        labelText:
                                            'Nome do montante (obrigatório)',
                                        hintText:
                                            'Exemplo: Entrega de outubro'),
                                    validator: (value) => value
                                                ?.trim()
                                                .isNotEmpty ==
                                            true
                                        ? null
                                        : 'Digite um nome para identificar este montante.'),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                    onPressed: !_editable
                                        ? null
                                        : () async {
                                            final date = await showDatePicker(
                                                context: context,
                                                initialDate: _date,
                                                firstDate: DateTime(2020),
                                                lastDate: DateTime(2100));
                                            if (date != null && mounted) {
                                              setState(() => _date = date);
                                            }
                                          },
                                    icon: const Icon(
                                        Icons.calendar_today_outlined),
                                    label: Text(
                                        'Data do montante: ${formatDate(_date)}')),
                                const SizedBox(height: 12),
                                FormField<List<String>>(
                                    initialValue: const [],
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    validator: (value) => value == null ||
                                            value.isEmpty
                                        ? 'Selecione pelo menos uma escola que participará deste montante.'
                                        : null,
                                    builder: (field) => Focus(
                                        focusNode: _schoolFocus,
                                        skipTraversal: true,
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Semantics(
                                                  header: true,
                                                  child: const Text(
                                                      'Escolas participantes (obrigatório)',
                                                      style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              const Text(
                                                  'Marque as escolas que receberão os alimentos. A escolha vale para todos os alimentos.'),
                                              Text(
                                                  '${_participatingSchools.length} escolas selecionadas'),
                                              for (final school in widget
                                                  .viewModel.knownSchools)
                                                CheckboxListTile(
                                                    key: ValueKey(
                                                        'batch-school-$school'),
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    controlAffinity:
                                                        ListTileControlAffinity
                                                            .leading,
                                                    title: Text(school),
                                                    value: _participatingSchools
                                                        .contains(school),
                                                    onChanged: !_editable
                                                        ? null
                                                        : (selected) =>
                                                            setState(() {
                                                              _priorSchools =
                                                                  null;
                                                              selected == true
                                                                  ? _participatingSchools
                                                                      .add(
                                                                          school)
                                                                  : _participatingSchools
                                                                      .remove(
                                                                          school);
                                                              field.didChange(
                                                                  _participatingSchools
                                                                      .toList());
                                                            })),
                                              Wrap(spacing: 8, children: [
                                                TextButton(
                                                    onPressed: !_editable
                                                        ? null
                                                        : () => setState(() {
                                                              _priorSchools =
                                                                  null;
                                                              _participatingSchools
                                                                  .addAll(widget
                                                                      .viewModel
                                                                      .knownSchools);
                                                              field.didChange(
                                                                  _participatingSchools
                                                                      .toList());
                                                            }),
                                                    child: const Text(
                                                        'Selecionar todas')),
                                                TextButton(
                                                    onPressed: !_editable ||
                                                            _participatingSchools
                                                                .isEmpty
                                                        ? null
                                                        : () => setState(() {
                                                              _priorSchools = {
                                                                ..._participatingSchools
                                                              };
                                                              _participatingSchools
                                                                  .clear();
                                                              field.didChange(
                                                                  const []);
                                                            }),
                                                    child: const Text(
                                                        'Limpar seleção')),
                                              ]),
                                              if (_priorSchools != null) ...[
                                                const GuidanceMessage(
                                                    'Seleção das escolas limpa. Você pode desfazer antes de continuar.',
                                                    error: false),
                                                OutlinedButton(
                                                    onPressed: !_editable
                                                        ? null
                                                        : () => setState(() {
                                                              _participatingSchools
                                                                  .addAll(
                                                                      _priorSchools!);
                                                              _priorSchools =
                                                                  null;
                                                              field.didChange(
                                                                  _participatingSchools
                                                                      .toList());
                                                            }),
                                                    child: const Text(
                                                        'Desfazer limpeza das escolas')),
                                              ],
                                              if (field.hasError)
                                                GuidanceMessage(
                                                    field.errorText!),
                                            ]))),
                                const SizedBox(height: 12),
                                const Text(
                                    'Escolha alimentos do catálogo. Use vírgula nas quantidades e preços. O preço é opcional; deixe vazio quando desconhecido.'),
                                for (var index = 0;
                                    index < _items.length;
                                    index++)
                                  _itemCard(_items[index], index),
                                if (_removed.isNotEmpty)
                                  Column(
                                      key: _undoKey,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        GuidanceMessage(
                                            '${_removed.last.$1.food ?? 'Alimento'} removido apenas deste rascunho. A opção de desfazer permanece disponível enquanto o cadastro estiver aberto.',
                                            error: false),
                                        OutlinedButton.icon(
                                            focusNode: _undoFocus,
                                            onPressed: !_editable
                                                ? null
                                                : () => setState(() {
                                                      final removed =
                                                          _removed.removeLast();
                                                      _items.insert(
                                                          removed.$2.clamp(
                                                              0, _items.length),
                                                          removed.$1);
                                                    }),
                                            icon: const Icon(Icons.undo),
                                            label: Text(
                                                'Desfazer remoção de ${_removed.last.$1.food ?? 'alimento'}')),
                                      ]),
                                TextButton.icon(
                                    onPressed: !_editable
                                        ? null
                                        : () => setState(
                                            () => _items.add(_ItemInputs())),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Adicionar alimento')),
                                const SizedBox(height: 12),
                                FilledButton(
                                    onPressed: _saving ? null : _submit,
                                    child: Text(_saving
                                        ? 'Salvando montante…'
                                        : _createdBatchId != null
                                            ? 'Tentar salvar no aparelho'
                                            : 'Salvar montante')),
                                TextButton(
                                    onPressed: _saving ? null : _close,
                                    child: const Text('Cancelar')),
                              ])))))));

  Widget _itemCard(_ItemInputs item, int index) => Card(
      key: ObjectKey(item),
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
                key: ValueKey('${identityHashCode(item)}-${item.food}'),
                itemHeight: null,
                focusNode: item.foodFocus,
                initialValue: item.food,
                isExpanded: true,
                decoration: InputDecoration(
                    labelText: 'Alimento ${index + 1} (obrigatório)'),
                items: [
                  for (final food in widget.viewModel.foods)
                    DropdownMenuItem(value: food.name, child: Text(food.name))
                ],
                onChanged: !_editable
                    ? null
                    : (value) => setState(() {
                          item.food = value;
                          final price = value == null
                              ? null
                              : findFood(value)?.priceCents;
                          item.price.text = price == null
                              ? ''
                              : (price / 100)
                                  .toStringAsFixed(2)
                                  .replaceAll('.', ',');
                        }),
                validator: (value) => value == null
                    ? 'Escolha um alimento da lista.'
                    : _items.where((entry) => entry.food == value).length > 1
                        ? 'Este alimento já está no montante. Escolha outro.'
                        : null),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final fields = [
                TextFormField(
                    controller: item.quantity,
                    enabled: _editable,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                        labelText:
                            'Quantidade ${item.food ?? ''} (kg, obrigatório)',
                        helperText: 'Exemplo: 10,5 kg'),
                    validator: (value) => _validKg(_parseKg(value)) &&
                            (_parseKg(value) ?? 0) >= .1
                        ? null
                        : 'Digite de 0,1 a 1.000.000 kg, em intervalos de 0,1. Exemplo: 10,5.'),
                TextFormField(
                    controller: item.price,
                    enabled: _editable,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                        labelText:
                            'Preço de ${item.food ?? 'alimento'} por kg (opcional)',
                        helperText: 'Exemplo: 5,72. Sem preço: deixe vazio.'),
                    validator: (value) => value?.trim().isEmpty == true ||
                            _parsePrice(value ?? '') != null
                        ? null
                        : 'Digite de 0,00 a 10.000,00, com até duas casas decimais.'),
              ];
              if (constraints.maxWidth < 500 ||
                  MediaQuery.textScalerOf(context).scale(14) > 18) {
                return Column(children: [
                  fields[0],
                  const SizedBox(height: 12),
                  fields[1]
                ]);
              }
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 12),
                    Expanded(child: fields[1])
                  ]);
            }),
            if (_items.length > 1)
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                      onPressed: !_editable ? null : () => _remove(item, index),
                      icon: const Icon(Icons.remove_circle_outline),
                      label: Text(
                          'Remover ${item.food ?? 'alimento ${index + 1}'}'))),
          ])));
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
  bool _busy = false;
  bool _saved = false;
  String? _saveError;

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
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(entry.key,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                TextFormField(
                                  key: Key('school-quantity-${entry.key}'),
                                  controller: entry.value,
                                  enabled: !_confirmed && !_busy,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textInputAction:
                                      entry.key == _quantities.keys.last
                                          ? TextInputAction.done
                                          : TextInputAction.next,
                                  decoration: InputDecoration(
                                      labelText:
                                          'Pedido de ${entry.key} (kg, opcional)',
                                      helperText:
                                          'Exemplo: 2,5. Sem pedido: deixe vazio.'),
                                  onChanged: (_) => setState(() {}),
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  validator: (value) {
                                    if (value?.trim().isNotEmpty == true &&
                                        !_validKg(_parseKg(value))) {
                                      return 'Digite de 0 a 1.000.000 kg, em intervalos de 0,1. Exemplo: 2,5.';
                                    }
                                    if (preview.requestedKg >
                                        _delivery.availableKg + 1e-7) {
                                      return 'A soma ultrapassa o recebido. Reduza os pedidos em ${formatKg(preview.shortageKg)}.';
                                    }
                                    return null;
                                  },
                                ),
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
          if (_saveError != null) GuidanceMessage(_saveError!),
          if (!_confirmed)
            FilledButton.icon(
                onPressed: _busy ? null : _confirmSave,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salvar rateio'))
          else ...[
            FilledButton.icon(
                onPressed: _busy ? null : _classify,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Informar sobra ou perda')),
            TextButton(
                onPressed:
                    _busy ? null : () => setState(() => _confirmed = false),
                child: const Text('Revisar pedidos')),
          ],
        ]),
      )),
    );
  }

  Future<void> _classify() async {
    if (_busy || _saved) return;
    setState(() => _busy = true);
    try {
      final preview = widget.viewModel.previewRequests(_delivery.id, _requests);
      final loss = await showDialog<double>(
          context: context,
          barrierDismissible: false,
          builder: (_) =>
              _ClassifyBalanceDialog(remainderKg: preview.remainderKg));
      if (loss != null && mounted) await _persist(loss);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmSave() async {
    if (_busy || _saved) return;
    if (!validateAccessibleForm(_form)) return;
    setState(() {
      _busy = true;
      _saveError = null;
    });
    try {
      final preview = widget.viewModel.previewRequests(_delivery.id, _requests);
      if (preview.remainderKg <= 1e-7) {
        await _persist(0);
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
            canPop: false,
            child: AlertDialog(
              scrollable: true,
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _persist(double loss) async {
    if (_saved) return;
    if (_delivery.status == DeliveryStatus.completed) {
      final accepted = await confirmDiscard(context,
          title: 'Substituir rateio de ${_delivery.product}?',
          consequence:
              'O rateio de ${_delivery.product} no montante ${_delivery.batchName} será substituído pelos pedidos, sobras e perdas deste formulário. Ao sincronizar, a mudança será enviada ao banco. Não há histórico para desfazer essa substituição.',
          action: 'Substituir rateio');
      if (!accepted || !mounted) return;
    }
    var recorded = false;
    try {
      widget.viewModel.saveRequests(_delivery.id, _requests,
          remainderConfirmed: _confirmed, lossKg: loss);
      recorded = true;
      await widget.viewModel.sync?.persist();
      if (!mounted) return;
      _saved = true;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(
          duration: Duration(seconds: 12),
          content: Text(
              'Rateio salvo neste aparelho. Sincronize no Perfil para compartilhar.')));
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(() => _saveError =
            '${error.message} Revise os pedidos e tente novamente.');
      }
    } on StateError {
      if (mounted) {
        setState(() => _saveError = recorded
            ? 'Não conseguimos gravar no aparelho. Mantenha esta tela aberta, confira o espaço disponível e tente salvar novamente.'
            : 'Há uma sincronização em andamento. Aguarde e tente salvar novamente.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saveError =
            'Não conseguimos gravar no aparelho. Seus valores foram mantidos nesta tela. Confira o espaço disponível e tente salvar novamente.');
      }
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
  final _kindFocus = FocusNode();
  @override
  void dispose() {
    _kindFocus.dispose();
    _loss.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      child: AlertDialog(
        scrollable: true,
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
                            itemHeight: null,
                            focusNode: _kindFocus,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Destino do saldo (obrigatório)'),
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
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                  labelText:
                                      'Quantidade perdida (kg, obrigatório)',
                                  helperText:
                                      'Exemplo: 2,5. O restante será sobra aproveitável.'),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              validator: (value) => _validKg(_parseKg(value)) &&
                                      (_parseKg(value) ?? 0) > 0 &&
                                      _parseKg(value)! <=
                                          widget.remainderKg + 1e-7
                                  ? null
                                  : 'Digite uma perda maior que zero e de até ${formatKg(widget.remainderKg)}, em intervalos de 0,1 kg.',
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
                if (validateAccessibleForm(_form)) {
                  Navigator.of(context)
                      .pop(_kind == 'loss' ? _parseKg(_loss.text)! : 0.0);
                }
              },
              child: const Text('Salvar classificação')),
        ],
      ));
}
