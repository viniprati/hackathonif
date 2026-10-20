import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nativa/data/auth_repository.dart';

void main() {
  test('envia credenciais via POST e guarda token somente após sucesso',
      () async {
    final repository = AuthRepository(
      baseUrl: 'http://localhost:3000/',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'http://localhost:3000/v1/auth/login');
        expect(request.url.query, isEmpty);
        expect(jsonDecode(request.body),
            {'cpf': '00000000000', 'password': 'somente-teste'});
        return http.Response(
            jsonEncode({
              'accessToken': 'test-token',
              'tokenType': 'Bearer',
              'expiresIn': 3600
            }),
            200);
      }),
    );
    addTearDown(repository.dispose);
    await repository.signIn('00000000000', 'somente-teste');
    expect(repository.isAuthenticated, isTrue);
    expect(repository.accessToken, 'test-token');
    repository.signOut();
    expect(repository.isAuthenticated, isFalse);
    expect(repository.accessToken, isNull);
  });

  for (final status in [401, 429, 500]) {
    test('HTTP $status não cria sessão nem expõe resposta do servidor',
        () async {
      final repository = AuthRepository(
          client: MockClient(
              (_) async => http.Response('secret-server-response', status)));
      addTearDown(repository.dispose);
      await expectLater(
          repository.signIn('00000000000', 'incorreta'),
          throwsA(isA<AuthFailure>().having((e) => e.message, 'message',
              isNot(contains('secret-server-response')))));
      expect(repository.accessToken, isNull);
    });
  }

  for (final body in [
    'not-json',
    '{}',
    '{"accessToken":"","tokenType":"Bearer","expiresIn":3600}'
  ]) {
    test('resposta inválida não abre sessão: $body', () async {
      final repository = AuthRepository(
          client: MockClient((_) async => http.Response(body, 200)));
      addTearDown(repository.dispose);
      await expectLater(repository.signIn('00000000000', 'somente-teste'),
          throwsA(isA<AuthFailure>()));
      expect(repository.isAuthenticated, isFalse);
    });
  }

  test('falha de rede bloqueia acesso, sem fallback local', () async {
    final repository = AuthRepository(
        client: MockClient(
            (_) async => throw http.ClientException('network-error')));
    addTearDown(repository.dispose);
    await expectLater(repository.signIn('00000000000', 'somente-teste'),
        throwsA(isA<AuthFailure>()));
    expect(repository.isAuthenticated, isFalse);
  });

  test('recusa enviar senha sem HTTPS para endereço remoto', () async {
    var requested = false;
    final repository = AuthRepository(
        baseUrl: 'http://example.com',
        client: MockClient((_) async {
          requested = true;
          return http.Response('{}', 200);
        }));
    addTearDown(repository.dispose);
    await expectLater(repository.signIn('00000000000', 'somente-teste'),
        throwsA(isA<AuthFailure>()));
    expect(requested, isFalse);
  });
}
