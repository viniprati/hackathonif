import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:nativa/data/auth_repository.dart';
import 'package:nativa/main.dart';

AuthRepository testAuthRepository() => AuthRepository(
      client: MockClient((_) async => http.Response(
          jsonEncode({
            'accessToken': 'only-a-widget-test-token',
            'tokenType': 'Bearer',
            'expiresIn': 3600,
          }),
          200)),
    );

NativaApp testApp(WidgetTester tester) {
  PackageInfo.setMockInitialValues(
      appName: 'Nativa',
      packageName: 'test.nativa',
      version: '9.8.7',
      buildNumber: '42',
      buildSignature: '');
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  return NativaApp(authRepository: testAuthRepository());
}
