import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nativa/data/auth_repository.dart';
import 'package:nativa/data/notifications.dart';
import 'package:nativa/data/push_subscription.dart';
import 'package:nativa/data/sync_store.dart';

class TestPush implements PushSubscription {
  bool subscribed = false, fail = false;
  @override
  bool get available => true;
  @override
  Future<void> enable({bool requestPermission = true}) async {
    if (fail) throw const PushFailure('Permita as notificações no Android.');
    subscribed = true;
  }

  @override
  Future<void> disable() async {
    if (fail) throw const PushFailure('Confira a internet e tente novamente.');
    subscribed = false;
  }

  @override
  void dispose() {}
}

void main() {
  test('Android disponibiliza push no build padrão, sem flag adicional', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final auth = AuthRepository();
    addTearDown(auth.dispose);
    final push = AndroidPushSubscription(auth,
        onNotice: () {}, onOpen: () {}, onError: (_) {});
    addTearDown(push.dispose);
    expect(push.available, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(push.available, isFalse);
  });
  test(
      'avisos compartilhados, opção e leitura persistem; falha mantém última lista',
      () async {
    var offline = false;
    final auth = AuthRepository(client: MockClient((request) async {
      if (request.url.path.endsWith('/login')) {
        return http.Response(
            '{"accessToken":"test","tokenType":"Bearer","expiresIn":3600}',
            200);
      }
      expect(request.headers['authorization'], 'Bearer test');
      if (offline) throw http.ClientException('private-network-error');
      return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'notice-test',
                'batchName': 'Teste compartilhado',
                'type': 'created',
                'createdAt': '2026-10-20T12:00:00Z'
              }
            ]
          }),
          200);
    }));
    addTearDown(auth.dispose);
    await auth.signIn('00000000000', 'only-test');
    final store = MemorySyncStore();
    final center = NotificationCenter(auth, store);
    await center.initialize();
    expect(center.enabled, isFalse);
    await center.setEnabled(true);
    expect(center.unread, 1);
    await center.markRead();
    expect(center.unread, 0);
    offline = true;
    await center.refresh();
    expect(center.notices.single.name, 'Teste compartilhado');
    expect(center.error, contains('Confira a internet'));
    expect(center.error, isNot(contains('private-network-error')));
    center.dispose();
    offline = false;
    final reopened = NotificationCenter(auth, store);
    addTearDown(reopened.dispose);
    await reopened.initialize();
    expect(reopened.enabled, isTrue);
    expect(reopened.unread, 0);
    await reopened.setEnabled(false);
    expect(jsonDecode(store.value!)['enabled'], false);
  });
  test('push requer confirmação efetiva e sair não finge desativação',
      () async {
    final auth = AuthRepository();
    addTearDown(auth.dispose);
    final push = TestPush();
    final center = NotificationCenter(auth, MemorySyncStore(), push: push);
    addTearDown(center.dispose);
    await center.initialize();
    push.fail = true;
    await center.setPushEnabled(true);
    expect(center.pushEnabled, isFalse);
    expect(center.error, contains('Permita'));
    push.fail = false;
    await center.setPushEnabled(true);
    expect(center.pushEnabled, isTrue);
    expect(push.subscribed, isTrue);
    push.fail = true;
    expect(await center.prepareSignOut(), isFalse);
    expect(center.pushEnabled, isTrue);
    push.fail = false;
    expect(await center.prepareSignOut(), isTrue);
    expect(push.subscribed, isFalse);
  });
}
