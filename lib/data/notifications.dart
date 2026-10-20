import 'push_subscription.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_repository.dart';
import 'sync_store.dart';

class BatchNotice {
  BatchNotice.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        name = json['batchName'] as String,
        completed = json['type'] == 'completed',
        createdAt = DateTime.parse(json['createdAt'] as String).toLocal();
  final String id, name;
  final bool completed;
  final DateTime createdAt;
  String get title =>
      completed ? 'Montante concluído' : 'Novo montante cadastrado';
}

/// Central compartilhada com consulta em primeiro plano e inscrição push opcional.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter(this.auth, this.store, {this.push});
  final PushSubscription? push;
  bool pushEnabled = false;
  final AuthRepository auth;
  final SyncStore store;
  bool enabled = false, busy = false, saving = false, loaded = false;
  bool _disposed = false, _foreground = true;
  String? error;
  List<BatchNotice> notices = [];
  Set<String> _read = {};
  Timer? _timer;
  int get unread => notices.where((n) => !_read.contains(n.id)).length;
  bool isRead(BatchNotice notice) => _read.contains(notice.id);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (saving) return;
    saving = true;
    error = null;
    _notify();
    try {
      final raw = await store.read();
      if (_disposed) return;
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        enabled = data['enabled'] as bool;
        pushEnabled = data['pushEnabled'] as bool? ?? false;
        _read = (data['read'] as List<dynamic>).cast<String>().toSet();
      }
      loaded = true;
      if (enabled) {
        _schedule();
        await refresh();
      }
      if (pushEnabled && push?.available == true) {
        try {
          await push!.enable(requestPermission: false);
        } on PushFailure catch (failure) {
          error = failure.message;
        } catch (_) {
          error =
              'Não conseguimos reativar o push. Desative e ative a opção para tentar novamente.';
        }
      }
    } catch (_) {
      error =
          'Não conseguimos abrir suas preferências de avisos. Toque em Tentar novamente.';
    }
    saving = false;
    _notify();
  }

  void foreground(bool value) {
    _foreground = value;
    _schedule();
    if (value && enabled) unawaited(refresh());
  }

  void _schedule() {
    _timer?.cancel();
    if (!_disposed && _foreground && enabled) {
      _timer = Timer.periodic(
          const Duration(seconds: 30), (_) => unawaited(refresh()));
    }
  }

  Future<void> _save(bool value, Set<String> read) => store.write(jsonEncode({
        'enabled': value,
        'pushEnabled': pushEnabled,
        'read': read.toList().take(200).toList()
      }));
  Future<void> setPushEnabled(bool value) async {
    if (saving || !loaded || push == null) return;
    saving = true;
    error = null;
    _notify();
    final previous = pushEnabled;
    try {
      if (value) {
        await push!.enable();
      } else {
        await push!.disable();
      }
      pushEnabled = value;
      try {
        await _save(enabled, _read);
      } catch (_) {
        error =
            'A opção de push foi atualizada no servidor, mas não conseguimos gravar a preferência no aparelho. Confira o espaço disponível e selecione a opção novamente antes de fechar o app.';
      }
    } on PushFailure catch (failure) {
      error = failure.message;
      pushEnabled = previous;
    } catch (_) {
      pushEnabled = previous;
      error =
          'Não conseguimos salvar a opção de push. Confira a internet e o espaço no aparelho e tente novamente.';
      // Se a preferência falhar após inscrição, remove a inscrição efetiva.
      if (value && !previous) {
        try {
          await push!.disable();
        } catch (_) {}
      }
    } finally {
      saving = false;
      _notify();
    }
  }

  Future<bool> prepareSignOut() async {
    if (saving) return false;
    if (!pushEnabled) return true;
    await setPushEnabled(false);
    return !pushEnabled;
  }

  Future<void> setEnabled(bool value) async {
    if (saving || !loaded) return;
    saving = true;
    error = null;
    _notify();
    try {
      await _save(value, _read);
      if (_disposed) return;
      enabled = value;
      _schedule();
      if (enabled) await refresh();
    } catch (_) {
      error =
          'Não conseguimos salvar a opção de avisos. A configuração anterior foi mantida. Tente novamente.';
    } finally {
      saving = false;
      _notify();
    }
  }

  Future<void> markRead() async {
    if (saving || !loaded) return;
    saving = true;
    _notify();
    final next = {...notices.map((n) => n.id), ..._read}.take(200).toSet();
    try {
      await _save(enabled, next);
      if (!_disposed) _read = next;
    } catch (_) {
      error = 'Não conseguimos marcar os avisos como lidos. Tente novamente.';
    } finally {
      saving = false;
      _notify();
    }
  }

  Future<void> refresh({bool force = false}) async {
    if (_disposed || busy || (!enabled && !force) || !auth.isAuthenticated) {
      return;
    }
    busy = true;
    error = null;
    _notify();
    try {
      final response =
          await auth.authenticatedRequest('GET', 'v1/notifications');
      if (_disposed || (!enabled && !force)) return;
      if (response.statusCode != 200) {
        error = response.statusCode == 401
            ? 'Sua sessão expirou. Entre novamente para consultar os avisos.'
            : response.statusCode == 404
                ? 'Os avisos ainda não estão disponíveis nesta versão do servidor. Atualize o backend e tente novamente.'
                : 'O serviço de avisos está indisponível. Aguarde e tente novamente.';
        return;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final next = (json['data'] as List<dynamic>)
          .map((v) => BatchNotice.fromJson(v as Map<String, dynamic>))
          .toList();
      notices = next;
    } on TimeoutException {
      error =
          'A consulta de avisos demorou para responder. Confira a internet e tente novamente.';
    } on http.ClientException {
      error =
          'Não conseguimos buscar os avisos. Confira a internet e tente novamente.';
    } catch (_) {
      error =
          'Não conseguimos ler os avisos do serviço. Tente novamente mais tarde.';
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    push?.dispose();
    super.dispose();
  }
}
