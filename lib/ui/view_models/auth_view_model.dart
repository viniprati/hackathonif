import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repository);
  final AuthRepository _repository;
  Timer? _expiration;
  bool _busy = false;
  bool _disposed = false;
  String? _error;
  bool get busy => _busy;
  String? get error => _error;
  bool get isAuthenticated => _repository.isAuthenticated;

  Future<void> signIn(String cpf, String password) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.signIn(cpf, password);
      if (_disposed) return;
      _expiration?.cancel();
      _expiration =
          Timer(_repository.expiresAt!.difference(DateTime.now()), () {
        _repository.signOut();
        _error = 'Sua sessão expirou. Entre novamente.';
        notifyListeners();
      });
    } on AuthFailure catch (failure) {
      _error = failure.message;
    } catch (_) {
      _repository.signOut();
      _error = 'Não foi possível entrar. Tente novamente.';
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void signOut() {
    _expiration?.cancel();
    _repository.signOut();
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _expiration?.cancel();
    _repository.dispose();
    super.dispose();
  }
}
