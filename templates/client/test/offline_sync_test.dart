import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:__PROJECT_NAME__/data/app_database.dart';
import 'package:__PROJECT_NAME__/data/session.dart';
import 'package:__PROJECT_NAME__/sync/sync_api.dart';
import 'package:__PROJECT_NAME__/sync/sync_engine.dart';

Session session({int userId = 1, String origin = 'https://example.com'}) => Session(
  origin: origin, userId: userId, name: 'Test', token: 'test-token',
  expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
  deviceId: 'b5d6f507-f3ea-4f88-a617-41dc9f61b48a',
);

void main() {
  test('local draft and outbox survive closing and reopening the database', () async {
    final folder = Directory.systemTemp.createTempSync('offline-draft-');
    final file = File('${folder.path}/test.sqlite');
    final owner = session();
    var database = AppDatabase(NativeDatabase(file));
    await database.createDraft(scope: owner.scope, deviceId: owner.deviceId, title: 'Offline');
    await database.close();
    database = AppDatabase(NativeDatabase(file));
    expect((await database.watchDrafts(owner.scope).first).single.title, 'Offline');
    expect((await database.pending(owner.scope, DateTime.now().toUtc())).length, 1);
    await database.close();
    folder.deleteSync(recursive: true);
  });

  test('lost acknowledgement retries the exact same operation and clears outbox only after ack', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final owner = session();
    await database.createDraft(scope: owner.scope, deviceId: owner.deviceId, title: 'A');
    final operation = (await database.pending(owner.scope, DateTime.now().toUtc())).single;
    final sent = <String>[];
    var loseFirstResponse = true;
    final api = SyncApi(MockClient((request) async {
      if (request.method == 'POST') {
        sent.add(request.body);
        if (loseFirstResponse) { loseFirstResponse = false; throw const SocketException('ack lost'); }
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'data': {'draft_id': payload['draft_id'], 'server_sequence': 1}}), 200);
      }
      return http.Response(jsonEncode({'data': [], 'next_cursor': 0, 'has_more': false}), 200);
    }));
    final engine = SyncEngine(database, api);
    await engine.synchronize(owner);
    expect((await database.watchDrafts(owner.scope).first).single.state, 'queued');
    // Simulate restart and passage of the persisted backoff interval.
    await database.customStatement('UPDATE outbox SET next_attempt_at = 0');
    await engine.synchronize(owner);
    expect(sent, [operation.payload, operation.payload]);
    expect(await database.pending(owner.scope, DateTime.now().toUtc()), isEmpty);
    expect((await database.watchDrafts(owner.scope).first).single.state, 'synced');
  });

  test('different accounts and server origins never send each others pending drafts', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final first = session();
    await database.createDraft(scope: first.scope, deviceId: first.deviceId, title: 'Private draft');
    var pushes = 0;
    final api = SyncApi(MockClient((request) async {
      if (request.method == 'POST') { pushes++; }
      return http.Response(jsonEncode({'data': [], 'next_cursor': 0, 'has_more': false}), 200);
    }));
    final engine = SyncEngine(database, api);
    await engine.synchronize(session(userId: 2));
    await engine.synchronize(session(origin: 'https://other.example.com'));
    expect(pushes, 0);
    expect(await database.watchDrafts(session(userId: 2).scope).first, isEmpty);
    expect((await database.pending(first.scope, DateTime.now().toUtc())).length, 1);
  });

  test('422 is retained as rejected without advancing the operation', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final owner = session();
    await database.createDraft(scope: owner.scope, deviceId: owner.deviceId, title: 'Needs review');
    final api = SyncApi(MockClient((request) async => request.method == 'POST'
      ? http.Response('{}', 422)
      : http.Response(jsonEncode({'data': [], 'next_cursor': 0, 'has_more': false}), 200)));
    await SyncEngine(database, api).synchronize(owner);
    expect((await database.watchDrafts(owner.scope).first).single.state, 'rejected');
    expect(await database.pending(owner.scope, DateTime.now().toUtc()), isEmpty);
    expect((await database.select(database.outbox).get()).single.blocked, isTrue);
  });

  test('401 leaves the pending operation available for the owner to log in again', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final owner = session();
    await database.createDraft(scope: owner.scope, deviceId: owner.deviceId, title: 'Still local');
    final api = SyncApi(MockClient((request) async => http.Response('{}', 401)));
    final engine = SyncEngine(database, api);
    await engine.synchronize(owner);
    expect(engine.authenticationRequired, isTrue);
    expect((await database.pending(owner.scope, DateTime.now().toUtc())).length, 1);
    expect((await database.watchDrafts(owner.scope).first).single.state, 'queued');
  });

  test('pull cursor and remote data commit atomically', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final owner = session();
    final row = {'draft_id': 'remote-draft', 'title': 'Remote', 'notes': null,
      'server_sequence': 8, 'created_at': '2026-01-01T00:00:00Z'};
    await database.applyPull(owner.scope, [row], 8);
    expect(await database.cursor(owner.scope), 8);
    await expectLater(database.applyPull(owner.scope, [{'invalid': true}], 9), throwsA(anything));
    expect(await database.cursor(owner.scope), 8);
    expect((await database.watchDrafts(owner.scope).first).single.state, 'synced');
  });
}
