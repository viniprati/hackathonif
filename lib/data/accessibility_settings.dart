import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'sync_store.dart';

class AccessibilitySettings extends ChangeNotifier {
  AccessibilitySettings(this.store);
  final SyncStore store;
  bool highContrast = false;
  bool loaded = false;
  bool busy = false;
  String? message;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (busy) return;
    busy = true;
    message = null;
    _notify();
    try {
      final raw = await store.read();
      if (raw != null) {
        final value = jsonDecode(raw) as Map<String, dynamic>;
        if (value['highContrast'] is! bool) throw const FormatException();
        highContrast = value['highContrast'] as bool;
      }
      loaded = true;
    } catch (_) {
      message =
          'Não conseguimos abrir sua preferência de contraste. Toque em Tentar novamente. Seus dados não foram apagados.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> setHighContrast(bool enabled) async {
    if (busy || !loaded) return;
    busy = true;
    message = null;
    _notify();
    try {
      await store.write(jsonEncode({'highContrast': enabled}));
      highContrast = enabled;
    } catch (_) {
      message =
          'Não conseguimos salvar o contraste no aparelho. A configuração anterior foi mantida. Tente novamente.';
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
