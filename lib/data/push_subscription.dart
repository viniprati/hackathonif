import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'auth_repository.dart';

class PushFailure implements Exception {
  const PushFailure(this.message);
  final String message;
}

abstract interface class PushSubscription {
  bool get available;
  Future<void> enable({bool requestPermission = true});
  Future<void> disable();
  void dispose();
}

/// Android: mensagens com payload notification são exibidas pelo FCM em segundo plano.
class AndroidPushSubscription implements PushSubscription {
  AndroidPushSubscription(this.auth,
      {required this.onNotice, required this.onOpen, required this.onError});
  final AuthRepository auth;
  final VoidCallback onNotice, onOpen;
  final ValueChanged<String> onError;
  static const _configured =
      bool.fromEnvironment('FIREBASE_ENABLED', defaultValue: true);
  @override
  bool get available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android && _configured;
  FirebaseMessaging? _messaging;
  String? _token;
  bool _disposed = false;
  StreamSubscription<String>? _tokens;
  StreamSubscription<RemoteMessage>? _messages, _opened;
  Future<void> _initialize() async {
    if (!available) {
      throw const PushFailure(
          'O push Android precisa da configuração Firebase deste aplicativo. Os avisos dentro do app continuam disponíveis.');
    }
    if (_messaging != null) return;
    // As opções nativas geradas pelo google-services.json permitem receber
    // notificações mesmo quando o processo Dart não estiver em execução.
    try {
      await Firebase.initializeApp();
    } catch (_) {
      throw const PushFailure(
          'O Firebase não foi configurado neste APK. Peça à equipe para configurar o aplicativo e tente novamente.');
    }
    _messaging = FirebaseMessaging.instance;
  }

  Future<void> _register(String token, bool enabled) async {
    final response = await auth.authenticatedRequest(
        'POST', 'v1/notifications/push',
        body: {'token': token, 'enabled': enabled});
    if (response.statusCode != 200) {
      final notConfigured = response.statusCode == 503 &&
          response.body.contains('PUSH_NOT_CONFIGURED');
      throw PushFailure(notConfigured
          ? 'O Firebase ainda não foi configurado no servidor. Peça à equipe para configurar e tente novamente.'
          : 'Não conseguimos atualizar o push no servidor. Confira a internet e tente novamente.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['enabled'] != enabled) {
      throw const PushFailure(
          'O servidor não confirmou a opção de push. Tente novamente.');
    }
  }

  @override
  Future<void> enable({bool requestPermission = true}) async {
    await _initialize();
    final permission = requestPermission
        ? await _messaging!.requestPermission()
        : await _messaging!.getNotificationSettings();
    if (permission.authorizationStatus != AuthorizationStatus.authorized &&
        permission.authorizationStatus != AuthorizationStatus.provisional) {
      throw const PushFailure(
          'O Android não permitiu os avisos. Ative as notificações do Nativa nas configurações do aparelho e tente novamente.');
    }
    final token = await _messaging!.getToken();
    if (token == null) {
      throw const PushFailure(
          'Não conseguimos registrar este aparelho para push. Confira a internet e tente novamente.');
    }
    await _register(token, true);
    _token = token;
    if (_disposed) return;
    _tokens ??= _messaging!.onTokenRefresh.listen((next) {
      unawaited(_register(next, true).then((_) {
        _token = next;
      }).catchError((Object _) {
        if (!_disposed) {
          onError(
              'Não conseguimos renovar o registro push. Desative e ative a opção para tentar novamente.');
        }
      }));
    });
    _messages ??= FirebaseMessaging.onMessage.listen((_) {
      if (!_disposed) onNotice();
    });
    _opened ??= FirebaseMessaging.onMessageOpenedApp.listen((_) {
      if (!_disposed) onOpen();
    });
    final initial = await _messaging!.getInitialMessage();
    if (initial != null && !_disposed) onOpen();
  }

  @override
  Future<void> disable() async {
    await _initialize();
    final token = _token ?? await _messaging!.getToken();
    if (token != null) await _register(token, false);
    await _tokens?.cancel();
    _tokens = null;
    await _messages?.cancel();
    _messages = null;
    await _opened?.cancel();
    _opened = null;
    _token = null;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_tokens?.cancel());
    unawaited(_messages?.cancel());
    unawaited(_opened?.cancel());
  }
}
