import 'package:nativa/data/batch_api.dart';
import 'package:nativa/domain/sync_batch.dart';

class FakeBatchApi implements BatchGateway {
  final Map<String, RemoteBatch> records = {};
  bool loseNextSaveResponse = false;
  SyncFailure? readFailure;
  Future<List<RemoteBatch>> Function()? onFetch;
  int writes = 0;
  int reads = 0;
  @override
  Future<List<RemoteBatch>> fetchAll() async {
    reads++;
    if (readFailure != null) throw readFailure!;
    if (onFetch != null) return onFetch!();
    return records.values.toList();
  }

  @override
  Future<RemoteBatch> get(String id) async =>
      records[id] ?? (throw const SyncFailure('Ausente', status: 404));
  @override
  Future<RemoteBatch> save(
      String id, int? revision, BatchSnapshot snapshot) async {
    final previous = records[id];
    if (previous?.snapshot.fingerprint == snapshot.fingerprint) {
      return previous!;
    }
    if (previous?.revision != revision) {
      throw const SyncFailure('Conflito', status: 409);
    }
    final next = RemoteBatch(
        id: id,
        revision: previous == null ? 0 : previous.revision + 1,
        snapshot: snapshot);
    records[id] = next;
    writes++;
    if (loseNextSaveResponse) {
      loseNextSaveResponse = false;
      throw const SyncFailure('Resposta perdida após gravar');
    }
    return next;
  }
}
