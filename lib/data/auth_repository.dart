import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://hackathonif-production.up.railway.app',
);

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}

/// Autentica no servidor. O token existe apenas durante esta sessão.
class AuthRepository {
  AuthRepository({http.Client? client, String baseUrl = apiBaseUrl})
      : _client = client ?? http.Client(),
        _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');

  final http.Client _client;
  final Uri _baseUri;
  String? _accessToken;
  DateTime? _expiresAt;

  String? get accessToken => isAuthenticated ? _accessToken : null;
  DateTime? get expiresAt => _expiresAt;
  bool get isAuthenticated =>
      _accessToken != null &&
      _expiresAt != null &&
      DateTime.now().isBefore(_expiresAt!);

  Future<void> signIn(String cpf, String password) async {
    signOut();
    final local =
        ['localhost', '127.0.0.1', '10.0.2.2', '::1'].contains(_baseUri.host);
    if (_baseUri.host.isEmpty ||
        (_baseUri.scheme != 'https' && !(_baseUri.scheme == 'http' && local))) {
      throw const AuthFailure('O endereço do serviço de acesso é inválido.');
    }
    try {
      final response = await _client
          .post(
            _baseUri.resolve('v1/auth/login'),
            headers: {
              'content-type': 'application/json',
              'accept': 'application/json'
            },
            body: jsonEncode({'cpf': cpf, 'password': password}),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 401) {
        throw const AuthFailure('CPF ou senha inválidos.');
      }
      if (response.statusCode == 429) {
        throw const AuthFailure(
            'Muitas tentativas. Aguarde um minuto e tente novamente.');
      }
      if (response.statusCode != 200) {
        throw const AuthFailure(
            'O serviço de acesso está indisponível. Tente novamente.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['tokenType'] != 'Bearer' ||
          decoded['accessToken'] is! String ||
          (decoded['accessToken'] as String).isEmpty ||
          decoded['expiresIn'] is! int ||
          (decoded['expiresIn'] as int) <= 0) {
        throw const AuthFailure(
            'Não foi possível confirmar o acesso. Tente novamente.');
      }
      _accessToken = decoded['accessToken'] as String;
      _expiresAt =
          DateTime.now().add(Duration(seconds: decoded['expiresIn'] as int));
    } on AuthFailure {
      rethrow;
    } on TimeoutException {
      throw const AuthFailure(
          'O serviço demorou para responder. Tente novamente.');
    } on http.ClientException {
      throw const AuthFailure(
          'Não foi possível conectar. Confira sua internet e tente novamente.');
    } on FormatException {
      throw const AuthFailure(
          'Não foi possível confirmar o acesso. Tente novamente.');
    }
  }

  void signOut() {
    _accessToken = null;
    _expiresAt = null;
  }

  void dispose() => _client.close();
}
