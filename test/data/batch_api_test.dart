import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nativa/data/auth_repository.dart';
import 'package:nativa/data/batch_api.dart';

void main() {
  for (final scenario in ['network', 'timeout', 'validation', 'server']) {
    test(
        'sincronização: orientação específica para $scenario sem detalhes técnicos',
        () async {
      final auth = AuthRepository(client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(
              '{"accessToken":"test-token","tokenType":"Bearer","expiresIn":3600}',
              200);
        }
        expect(request.headers['authorization'], 'Bearer test-token');
        if (scenario == 'network') throw http.ClientException('private-detail');
        if (scenario == 'timeout') throw TimeoutException('private-detail');
        return http.Response(
            'private-detail', scenario == 'validation' ? 422 : 503);
      }));
      addTearDown(auth.dispose);
      await auth.signIn('00000000000', 'only-test');
      await expectLater(
          BatchApi(auth).fetchAll(),
          throwsA(isA<SyncFailure>().having(
              (e) => e.message,
              'mensagem',
              allOf(
                isNot(contains('private-detail')),
                contains(switch (scenario) {
                  'network' => 'Confira sua internet',
                  'timeout' => 'demorou para responder',
                  'validation' => 'Revise alimentos',
                  _ => 'temporariamente indisponível',
                }),
              ))));
    });
  }
}
