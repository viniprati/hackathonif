import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SyncStore {
  Future<String?> read();
  Future<void> write(String value);
}

/// Cópia de trabalho para o MVP. O banco é a referência após sincronizar.
class PreferencesSyncStore implements SyncStore {
  PreferencesSyncStore(String apiUrl) : _key = 'nativa.manualSync.v1.$apiUrl';
  PreferencesSyncStore.accessibility() : _key = 'nativa.accessibility.v1';
  final String _key;
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  @override
  Future<String?> read() => _preferences.getString(_key);
  @override
  Future<void> write(String value) => _preferences.setString(_key, value);
}

class MemorySyncStore implements SyncStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}
