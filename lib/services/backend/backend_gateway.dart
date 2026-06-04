import 'dart:async';

import 'package:pocketbase/pocketbase.dart';

import '../app_exception.dart';
import 'pb_mapper.dart';
import 'pocketbase_client.dart';

final BackendGateway backendGateway = PocketBaseBackendGateway(() => pb);

abstract interface class BackendGateway {
  bool get isAuthValid;
  RecordModel? get authRecord;
  Stream<AuthStoreEvent> get authChanges;

  void clearAuth();

  Future<RecordAuth> authWithPassword(
      String collection, String email, String password);
  Future<RecordAuth> authRefresh(String collection);

  Future<List<RecordModel>> getFullList(
    String collection, {
    String? filter,
    String? sort,
    String? fields,
  });

  Future<ResultList<RecordModel>> getList(
    String collection, {
    int page = 1,
    int perPage = 30,
    String? filter,
    String? sort,
    String? fields,
  });

  Future<RecordModel> getOne(String collection, String id);
  Future<RecordModel> getFirstListItem(String collection, String filter);
  Future<RecordModel> create(String collection, Map<String, dynamic> body);
  Future<RecordModel> update(
      String collection, String id, Map<String, dynamic> body);
  Future<void> delete(String collection, String id);

  Future<int> nextNumericId(String collection);
  Future<RecordModel?> findByNumericId(String collection, int id);
  Future<String> requireRecordIdByNumericId(String collection, int id);
  Future<RecordModel?> findProfileBySourceId(String sourceId);

  Stream<List<T>> pollingListStream<T>(
    Future<List<T>> Function() loader, {
    Duration interval = const Duration(seconds: 30),
  });
}

class PocketBaseBackendGateway implements BackendGateway {
  PocketBaseBackendGateway(this._client);

  final PocketBase Function() _client;

  PocketBase get _pb => _client();

  @override
  bool get isAuthValid => _pb.authStore.isValid;

  @override
  RecordModel? get authRecord => _pb.authStore.record;

  @override
  Stream<AuthStoreEvent> get authChanges => _pb.authStore.onChange;

  @override
  void clearAuth() {
    _pb.authStore.clear();
  }

  @override
  Future<RecordAuth> authWithPassword(
    String collection,
    String email,
    String password,
  ) {
    return _pb.collection(collection).authWithPassword(email, password);
  }

  @override
  Future<RecordAuth> authRefresh(String collection) {
    return _pb.collection(collection).authRefresh();
  }

  @override
  Future<List<RecordModel>> getFullList(
    String collection, {
    String? filter,
    String? sort,
    String? fields,
  }) {
    return _pb.collection(collection).getFullList(
          filter: filter,
          sort: sort,
          fields: fields,
        );
  }

  @override
  Future<ResultList<RecordModel>> getList(
    String collection, {
    int page = 1,
    int perPage = 30,
    String? filter,
    String? sort,
    String? fields,
  }) {
    return _pb.collection(collection).getList(
          page: page,
          perPage: perPage,
          filter: filter,
          sort: sort,
          fields: fields,
        );
  }

  @override
  Future<RecordModel> getOne(String collection, String id) {
    return _pb.collection(collection).getOne(id);
  }

  @override
  Future<RecordModel> getFirstListItem(String collection, String filter) {
    return _pb.collection(collection).getFirstListItem(filter);
  }

  @override
  Future<RecordModel> create(String collection, Map<String, dynamic> body) {
    return _pb.collection(collection).create(body: body);
  }

  @override
  Future<RecordModel> update(
    String collection,
    String id,
    Map<String, dynamic> body,
  ) {
    return _pb.collection(collection).update(id, body: body);
  }

  @override
  Future<void> delete(String collection, String id) {
    return _pb.collection(collection).delete(id);
  }

  @override
  Future<int> nextNumericId(String collection) async {
    final records = await getFullList(collection, fields: 'id');
    var maxId = 0;
    for (final record in records) {
      final id = _numericIdFromRecordId(record.id);
      if (id != null && id > maxId) maxId = id;
    }
    return maxId + 1;
  }

  @override
  Future<RecordModel?> findByNumericId(String collection, int id) async {
    try {
      return await getOne(collection, numericRecordId(id));
    } on ClientException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<String> requireRecordIdByNumericId(String collection, int id) async {
    final record = await findByNumericId(collection, id);
    if (record == null) {
      throw RecordNotFoundException(collection, id);
    }
    return record.id;
  }

  @override
  Future<RecordModel?> findProfileBySourceId(String sourceId) async {
    try {
      return await getFirstListItem(
        'profiles',
        'source_id = "${escapeFilterValue(sourceId)}"',
      );
    } on ClientException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Stream<List<T>> pollingListStream<T>(
    Future<List<T>> Function() loader, {
    Duration interval = const Duration(seconds: 30),
  }) async* {
    yield await loader();
    yield* Stream.periodic(interval).asyncMap((_) => loader());
  }
}

int? _numericIdFromRecordId(String id) {
  if (RegExp(r'^\d{15}$').hasMatch(id)) {
    return int.tryParse(id);
  }
  return null;
}
