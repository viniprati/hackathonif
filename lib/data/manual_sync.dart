import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/sync_batch.dart';
import 'batch_api.dart';
import 'delivery_repository.dart';
import 'sync_store.dart';

class _Link {
  _Link(this.remoteId, this.revision, this.baseline);
  final String remoteId;
  final int? revision;
  final String? baseline;
  Map<String, Object?> toJson() =>
      {'remoteId': remoteId, 'revision': revision, 'baseline': baseline};
  factory _Link.fromJson(Map<String, dynamic> json) => _Link(
      json['remoteId'] as String,
      json['revision'] as int?,
      json['baseline'] as String?);
}

class SyncConflict {
  SyncConflict(this.localId, this.local, this.remote);
  final int localId;
  final BatchSnapshot local;
  final RemoteBatch? remote;
}

class ManualSync extends ChangeNotifier {
  ManualSync(
      {required this.repository, required this.api, required this.store});
  final DeliveryRepository repository;
  final BatchGateway api;
  final SyncStore store;
  final Map<int, _Link> _links = {};
  final List<SyncConflict> _conflicts = [];
  Future<void> _writes = Future<void>.value();
  bool _disposed = false;
  bool busy = false;
  bool sessionExpired = false;
  String? message;
  DateTime? lastSyncedAt;
  List<SyncConflict> get conflicts => List.unmodifiable(_conflicts);

  Map<int, List<Delivery>> get _groups {
    final groups = <int, List<Delivery>>{};
    for (final item in repository.getAll()) {
      groups.putIfAbsent(item.batchId, () => []).add(item);
    }
    return groups;
  }

  BatchSnapshot _snapshot(List<Delivery> values) =>
      BatchSnapshot.fromDeliveries(values, repository.schoolsForDelivery);
  int get pendingCount => _groups.entries
      .where((entry) =>
          _links[entry.key]?.baseline != _snapshot(entry.value).fingerprint)
      .length;

  Future<void> initialize() async {
    final raw = await store.read();
    if (raw == null) return;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['schema'] != 1) {
      throw const FormatException('Formato de cópia local desconhecido.');
    }
    final links = <int, _Link>{};
    final deliveries = <Delivery>[];
    final seen = <int>{};
    for (final raw in json['batches'] as List<dynamic>) {
      final record = raw as Map<String, dynamic>;
      final id = record['localId'] as int;
      if (!seen.add(id)) {
        throw const FormatException('Montante local repetido.');
      }
      final batch =
          BatchSnapshot.fromJson(record['data'] as Map<String, dynamic>);
      final itemIds = record['itemIds'] as Map<String, dynamic>;
      for (final item in batch.items) {
        deliveries
            .add(item.toDelivery(itemIds[item.product] as int, id, batch));
      }
      if (record['link'] != null) {
        links[id] = _Link.fromJson(record['link'] as Map<String, dynamic>);
      }
    }
    final date = json['lastSyncedAt'] as String?;
    final last = date == null ? null : DateTime.parse(date);
    // Só substitui a cópia em memória depois de conferir o arquivo inteiro.
    repository.restoreAll(deliveries);
    _links
      ..clear()
      ..addAll(links);
    lastSyncedAt = last;
  }

  String _encode() => jsonEncode({
        'schema': 1,
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
        'batches': _groups.entries
            .map((entry) => {
                  'localId': entry.key,
                  'data': _snapshot(entry.value).toJson(),
                  'itemIds': {
                    for (final item in entry.value) item.product: item.id
                  },
                  'link': _links[entry.key]?.toJson(),
                })
            .toList(),
      });

  Future<void> persist() {
    final encoded = _encode();
    final write = _writes.then((_) => store.write(encoded));
    _writes = write.catchError((Object _) {});
    return write;
  }

  void saveSoon() {
    unawaited(persist().catchError((Object _) {
      message =
          'Não foi possível salvar a cópia no aparelho. Sincronize antes de fechar o app.';
      _changed();
    }));
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _apply(int localId, RemoteBatch remote) {
    final previousIds = {
      for (final item in _groups[localId] ?? <Delivery>[]) item.product: item.id
    };
    repository.replaceBatch(
        localId,
        remote.snapshot.items
            .map((item) => item.toDelivery(
                previousIds[item.product] ?? repository.allocateDeliveryId(),
                localId,
                remote.snapshot))
            .toList());
    _links[localId] =
        _Link(remote.id, remote.revision, remote.snapshot.fingerprint);
  }

  void _conflict(int localId, BatchSnapshot local, RemoteBatch? remote) {
    _conflicts.removeWhere((item) => item.localId == localId);
    _conflicts.add(SyncConflict(localId, local, remote));
  }

  Future<void> synchronize() async {
    if (busy) return;
    busy = true;
    sessionExpired = false;
    message = null;
    _conflicts.clear();
    _changed();
    try {
      await persist();
      final incoming = {
        for (final remote in await api.fetchAll()) remote.id: remote
      };
      final groups = _groups;
      for (final entry in groups.entries) {
        if (_disposed) return;
        final localId = entry.key;
        final snapshot = _snapshot(entry.value);
        var link = _links[localId];
        if (link == null) {
          link = _Link(const Uuid().v4(), null, null);
          _links[localId] = link;
          // A chave de criação é salva antes da rede para que reenvios não dupliquem dados.
          await persist();
        }
        final remote = incoming.remove(link.remoteId);
        final dirty = link.baseline != snapshot.fingerprint;
        if (remote == null && link.revision != null) {
          _conflict(localId, snapshot, null);
          continue;
        }
        if (remote != null &&
            (!dirty || remote.snapshot.fingerprint == snapshot.fingerprint)) {
          _apply(localId, remote);
          await persist();
          continue;
        }
        if (remote != null && remote.snapshot.fingerprint != link.baseline) {
          _conflict(localId, snapshot, remote);
          continue;
        }
        try {
          final saved = await api.save(
              link.remoteId, remote?.revision ?? link.revision, snapshot);
          _apply(localId, saved);
          await persist();
        } on SyncFailure catch (failure) {
          if (failure.status != 409) rethrow;
          RemoteBatch? latest;
          try {
            latest = await api.get(link.remoteId);
          } on SyncFailure catch (failure) {
            if (failure.status != 404) rethrow;
          }
          _conflict(localId, snapshot, latest);
        }
      }
      for (final remote in incoming.values) {
        _apply(repository.allocateBatchId(), remote);
      }
      if (_conflicts.isEmpty) lastSyncedAt = DateTime.now();
      await persist();
      message = _conflicts.isEmpty
          ? 'Dados enviados e atualizados com sucesso.'
          : 'Os demais dados foram atualizados. Revise ${_conflicts.length} conflito(s); suas alterações locais foram mantidas.';
    } on SyncFailure catch (failure) {
      sessionExpired = failure.status == 401;
      message = failure.message;
    } on FormatException {
      message =
          'Os dados recebidos estão inconsistentes. A cópia local foi preservada.';
    } catch (_) {
      message =
          'Não foi possível concluir a sincronização. Os dados pendentes foram mantidos para tentar novamente.';
    } finally {
      busy = false;
      _changed();
    }
  }

  /// Chamado somente após confirmação explícita para descartar a edição local.
  Future<void> useServerVersion(int localId) async {
    if (busy) return;
    final link = _links[localId];
    if (link == null) return;
    busy = true;
    sessionExpired = false;
    _changed();
    try {
      try {
        _apply(localId, await api.get(link.remoteId));
      } on SyncFailure catch (failure) {
        if (failure.status != 404) rethrow;
        repository.replaceBatch(localId, []);
        _links.remove(localId);
      }
      await persist();
      _conflicts.removeWhere((item) => item.localId == localId);
      message =
          'A versão atual do banco foi carregada. Sincronize novamente para conferir todos os dados.';
    } on SyncFailure catch (failure) {
      sessionExpired = failure.status == 401;
      message = failure.message;
    } catch (_) {
      message = 'Não foi possível carregar a versão do banco. Tente novamente.';
    } finally {
      busy = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
