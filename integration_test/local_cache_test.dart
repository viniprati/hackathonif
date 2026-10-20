import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nativa/data/auth_repository.dart';
import 'package:nativa/data/sync_store.dart';
import 'package:nativa/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('APK release abre após login e restaura cache com plugin nativo',
      (tester) async {
    // Chave exclusiva; não lê nem altera os dados da API de demonstração.
    const url = 'https://nativa-cache-test.invalid/';
    final store = PreferencesSyncStore(url);
    await store.write(jsonEncode({
      'schema': 1,
      'lastSyncedAt': null,
      'batches': [
        {
          'localId': 1,
          'link': null,
          'itemIds': {'Aipim': 1},
          'data': {
            'name': 'Cache nativo isolado',
            'date': '2026-10-20',
            'participatingSchools': ['IFES'],
            'items': [
              {
                'product': 'Aipim',
                'receivedKg': 100,
                'unitPriceCents': 572,
                'invoiceNumber': null,
                'status': 'completed',
                'lossKg': 10,
                'requests': [
                  {'school': 'IFES', 'requestedKg': 60}
                ],
              }
            ],
          },
        }
      ],
    }));
    final restored = PreferencesSyncStore(url);
    expect(await restored.read(), contains('Cache nativo isolado'));
    var requests = 0;
    final auth = AuthRepository(
        baseUrl: url,
        client: MockClient((request) async {
          requests++;
          expect(request.url.path, '/v1/auth/login');
          return http.Response(
              jsonEncode({
                'accessToken': 'fixture-local-sem-servico-externo',
                'tokenType': 'Bearer',
                'expiresIn': 3600
              }),
              200);
        }));
    await tester
        .pumpWidget(NativaApp(authRepository: auth, syncStore: restored));
    await tester.enterText(find.byType(TextFormField).at(0), '00000000000');
    await tester.enterText(find.byType(TextFormField).at(1), 'fixture-local');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Não foi possível abrir os dados do aparelho. A cópia existente foi preservada.'),
        findsNothing);
    expect(find.text('Cache nativo isolado'), findsWidgets);
    expect(requests, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(await PreferencesSyncStore(url).read(),
        contains('Cache nativo isolado'));
  });
}
