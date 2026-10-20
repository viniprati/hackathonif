import 'dart:async';

import 'package:flutter/material.dart';

import '../data/manual_sync.dart';
import 'theme.dart';

class SyncCard extends StatefulWidget {
  const SyncCard(
      {super.key, required this.sync, required this.onSessionExpired});
  final ManualSync sync;
  final VoidCallback onSessionExpired;
  @override
  State<SyncCard> createState() => _SyncCardState();
}

class _SyncCardState extends State<SyncCard> {
  Future<void> _run(Future<void> Function() operation) async {
    if (widget.sync.busy) return;
    final sync = widget.sync;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
            canPop: false,
            child: AlertDialog(
                title: Text('Sincronizando dados'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Aguarde enquanto os dados são enviados e atualizados.'),
                ]))));
    unawaited(navigator.push(route));
    try {
      await operation();
    } finally {
      if (route.isActive && navigator.mounted) navigator.removeRoute(route);
    }
    if (mounted && sync.sessionExpired) widget.onSessionExpired();
  }

  Future<void> _review(SyncConflict conflict) async {
    final useBank = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              scrollable: true,
              title: const Text('Revisar conflito'),
              content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(conflict.local.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    const Text(
                        'Outra pessoa alterou este montante. Suas alterações estão preservadas no aparelho. Usar a versão do banco substituirá sua edição local.'),
                    const SizedBox(height: 16),
                    const Text('Neste aparelho',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(conflict.local.summary),
                    const SizedBox(height: 16),
                    const Text('No banco',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(conflict.remote?.snapshot.summary ??
                        'O montante não está mais no banco. Usar esta versão removerá somente a cópia deste aparelho.'),
                  ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Manter no aparelho')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Usar versão do banco')),
              ],
            ));
    if (useBank == true && mounted) {
      await _run(() => widget.sync.useServerVersion(conflict.localId));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.sync,
      builder: (context, _) {
        final sync = widget.sync;
        final last = sync.lastSyncedAt;
        return Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Dados compartilhados',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                          'Envie as alterações deste aparelho e busque as feitas por outras pessoas. A atualização acontece ao tocar no botão.'),
                      const SizedBox(height: 12),
                      Text(
                          '${sync.pendingCount} montante(s) com alterações locais pendentes.'),
                      const SizedBox(height: 8),
                      Text(last == null
                          ? 'Ainda não sincronizado.'
                          : 'Última sincronização: ${formatDate(last)} às ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                          onPressed:
                              sync.busy ? null : () => _run(sync.synchronize),
                          icon: const Icon(Icons.sync),
                          label: const Text('Sincronizar dados')),
                      if (sync.message != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Semantics(
                                liveRegion: true, child: Text(sync.message!))),
                      for (final conflict in sync.conflicts)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('Conflito: ${conflict.local.name}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  OutlinedButton(
                                      onPressed: sync.busy
                                          ? null
                                          : () => _review(conflict),
                                      child: const Text('Revisar versões')),
                                ])),
                    ])));
      });
}
