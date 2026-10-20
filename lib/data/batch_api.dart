import 'dart:convert';

import '../domain/sync_batch.dart';
import 'auth_repository.dart';

class SyncFailure implements Exception {
  const SyncFailure(this.message, {this.status});
  final String message;
  final int? status;
}

abstract interface class BatchGateway {
  Future<List<RemoteBatch>> fetchAll();
  Future<RemoteBatch> get(String id);
  Future<RemoteBatch> save(String id, int? revision, BatchSnapshot snapshot);
}

class BatchApi implements BatchGateway {
  BatchApi(this._auth);
  final AuthRepository _auth;

  Future<Map<String, dynamic>> _request(String method, String path,
      {Object? body}) async {
    final response = await _auth.authenticatedRequest(method, path, body: body);
    if (response.statusCode == 401) {
      throw const SyncFailure('Sua sessão expirou. Entre novamente.',
          status: 401);
    }
    if (response.statusCode == 409) {
      throw const SyncFailure('Outro usuário alterou este montante.',
          status: 409);
    }
    if (response.statusCode == 404) {
      throw const SyncFailure(
          'O montante ou o serviço de sincronização não está disponível.',
          status: 404);
    }
    if (response.statusCode == 429) {
      throw const SyncFailure(
          'Muitas requisições. Aguarde um minuto e sincronize novamente.',
          status: 429);
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw SyncFailure(
          response.statusCode == 400 || response.statusCode == 422
              ? 'O banco recusou os dados. Revise alimentos, escolas, quantidades e perdas.'
              : 'Não foi possível sincronizar agora. Tente novamente.',
          status: response.statusCode);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<List<RemoteBatch>> fetchAll() async {
    final results = <String, RemoteBatch>{};
    for (var page = 1; page <= 50; page++) {
      final data = await _request('GET', 'v1/batches?limit=100&page=$page');
      final lines = data['data'] as List<dynamic>;
      for (final raw in lines) {
        final batch = RemoteBatch.fromJson(raw as Map<String, dynamic>);
        results[batch.id] = batch;
      }
      if (page * 100 >= (data['total'] as int)) return results.values.toList();
      if (lines.isEmpty) {
        throw const SyncFailure(
            'A lista do banco mudou. Tente sincronizar novamente.');
      }
    }
    throw const SyncFailure(
        'O volume de dados ultrapassa o limite desta versão.');
  }

  @override
  Future<RemoteBatch> get(String id) async =>
      RemoteBatch.fromJson(await _request('GET', 'v1/batches/$id'));
  @override
  Future<RemoteBatch> save(
          String id, int? revision, BatchSnapshot snapshot) async =>
      RemoteBatch.fromJson(await _request('PUT', 'v1/batches/$id/sync',
          body: {...snapshot.toJson(), 'revision': revision}));
}
