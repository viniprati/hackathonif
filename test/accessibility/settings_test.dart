import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nativa/data/accessibility_settings.dart';
import 'package:nativa/data/sync_store.dart';

class FailingPreferenceStore extends MemorySyncStore {
  @override
  Future<void> write(String value) async =>
      throw StateError('armazenamento indisponível');
}

class DelayedPreferenceStore extends MemorySyncStore {
  final pending = Completer<void>();
  int writes = 0;
  @override
  Future<void> write(String value) async {
    writes++;
    await pending.future;
    await super.write(value);
  }
}

void main() {
  test('alto contraste é restaurado após reiniciar o controlador', () async {
    final store = MemorySyncStore();
    final first = AccessibilitySettings(store);
    await first.load();
    await first.setHighContrast(true);
    first.dispose();
    final second = AccessibilitySettings(store);
    addTearDown(second.dispose);
    await second.load();
    expect(second.highContrast, isTrue);
    await second.setHighContrast(false);
    expect(store.value, contains('false'));
  });
  test('falha ao salvar mantém preferência anterior e orienta nova tentativa',
      () async {
    final store = FailingPreferenceStore()..value = '{"highContrast":true}';
    final settings = AccessibilitySettings(store);
    addTearDown(settings.dispose);
    await settings.load();
    await settings.setHighContrast(false);
    expect(settings.highContrast, isTrue);
    expect(store.value, '{"highContrast":true}');
    expect(settings.message, contains('configuração anterior foi mantida'));
    expect(settings.busy, isFalse);
  });
  test('toques repetidos não geram gravações concorrentes', () async {
    final store = DelayedPreferenceStore();
    final settings = AccessibilitySettings(store);
    addTearDown(settings.dispose);
    await settings.load();
    final saving = settings.setHighContrast(true);
    await settings.setHighContrast(false);
    expect(store.writes, 1);
    expect(settings.highContrast, isFalse);
    store.pending.complete();
    await saving;
    expect(settings.highContrast, isTrue);
  });
  test('preferência inválida não é apagada ou substituída silenciosamente',
      () async {
    final store = MemorySyncStore()..value = '{"highContrast":"inválido"}';
    final settings = AccessibilitySettings(store);
    addTearDown(settings.dispose);
    await settings.load();
    await settings.setHighContrast(true);
    expect(settings.loaded, isFalse);
    expect(store.value, '{"highContrast":"inválido"}');
    expect(settings.message, contains('Tentar novamente'));
  });
}
