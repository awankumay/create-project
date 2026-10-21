import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

class Drafts extends Table {
  TextColumn get scope => text()();
  TextColumn get uuid => text()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get state => text().withDefault(const Constant('queued'))();
  IntColumn get serverSequence => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {scope, uuid};
}

@DataClassName('QueuedOperation')
class Outbox extends Table {
  TextColumn get operationId => text()();
  TextColumn get scope => text()();
  TextColumn get draftId => text()();
  TextColumn get payload => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime()();
  BoolColumn get blocked => boolean().withDefault(const Constant(false))();
  TextColumn get lastError => text().nullable()();
  @override
  Set<Column> get primaryKey => {operationId};
}

class PullCursors extends Table {
  TextColumn get scope => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {scope};
}

@DriftDatabase(tables: [Drafts, Outbox, PullCursors])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor executor) : super(executor);
  @override
  int get schemaVersion => 1;

  Future<void> createDraft({required String scope, required String deviceId,
      required String title, String? notes}) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || cleanTitle.length > 120 || (notes?.length ?? 0) > 2000) {
      throw ArgumentError('Judul wajib, maksimal 120 karakter; catatan maksimal 2000.');
    }
    final draftId = const Uuid().v4();
    final operationId = const Uuid().v4();
    final now = DateTime.now().toUtc();
    await transaction(() async {
      await into(drafts).insert(DraftsCompanion.insert(scope: scope, uuid: draftId,
        title: cleanTitle, notes: Value(notes), createdAt: now));
      await into(outbox).insert(OutboxCompanion.insert(operationId: operationId,
        scope: scope, draftId: draftId, nextAttemptAt: now,
        payload: jsonEncode({'operation_id': operationId, 'draft_id': draftId,
          'device_id': deviceId, 'title': cleanTitle, 'notes': notes})));
    });
  }

  Stream<List<Draft>> watchDrafts(String owner) => (select(drafts)
    ..where((row) => row.scope.equals(owner))
    ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).watch();

  Future<List<QueuedOperation>> pending(String owner, DateTime now) => (select(outbox)
    ..where((row) => row.scope.equals(owner) & row.blocked.equals(false) & row.nextAttemptAt.isSmallerOrEqualValue(now))
    ..orderBy([(row) => OrderingTerm.asc(row.nextAttemptAt)])
    ..limit(50)).get();

  Future<void> acknowledge(QueuedOperation operation, int sequence) => transaction(() async {
    await (update(drafts)..where((d) => d.scope.equals(operation.scope) & d.uuid.equals(operation.draftId)))
      .write(DraftsCompanion(state: const Value('synced'), serverSequence: Value(sequence)));
    await (delete(outbox)..where((o) => o.operationId.equals(operation.operationId))).go();
  });

  Future<void> recordFailure(QueuedOperation operation, String message, {required bool permanent}) => transaction(() async {
    final attempt = operation.attempts + 1;
    final seconds = (1 << attempt.clamp(1, 8).toInt()) + const Uuid().v4().codeUnitAt(0) % 5;
    await (update(outbox)..where((o) => o.operationId.equals(operation.operationId)))
      .write(OutboxCompanion(attempts: Value(attempt), blocked: Value(permanent),
        lastError: Value(message), nextAttemptAt: Value(DateTime.now().toUtc().add(Duration(seconds: seconds)))));
    if (permanent) {
      await (update(drafts)..where((d) => d.scope.equals(operation.scope) & d.uuid.equals(operation.draftId)))
        .write(const DraftsCompanion(state: Value('rejected')));
    }
  });

  Future<int> cursor(String owner) async => (await (select(pullCursors)
    ..where((c) => c.scope.equals(owner))).getSingleOrNull())?.position ?? 0;

  Future<void> applyPull(String owner, List<dynamic> rows, int position) => transaction(() async {
    for (final raw in rows) {
      final data = raw as Map<String, dynamic>;
      final existing = await (select(drafts)..where((d) => d.scope.equals(owner) & d.uuid.equals(data['draft_id'] as String))).getSingleOrNull();
      // A pull cannot acknowledge a pending operation: only its push response can.
      if (existing != null && existing.state != 'synced') continue;
      await into(drafts).insertOnConflictUpdate(DraftsCompanion.insert(scope: owner,
        uuid: data['draft_id'] as String, title: data['title'] as String,
        notes: Value(data['notes'] as String?), state: const Value('synced'),
        serverSequence: Value(data['server_sequence'] as int),
        createdAt: DateTime.parse(data['created_at'] as String).toUtc()));
    }
    await into(pullCursors).insertOnConflictUpdate(PullCursorsCompanion.insert(scope: owner, position: Value(position)));
  });

  Future<void> retryRejected(String owner) => transaction(() async {
    await (update(outbox)..where((o) => o.scope.equals(owner) & o.blocked.equals(true)))
      .write(OutboxCompanion(blocked: const Value(false), nextAttemptAt: Value(DateTime.now().toUtc()), lastError: const Value(null)));
    await (update(drafts)..where((d) => d.scope.equals(owner) & d.state.equals('rejected')))
      .write(const DraftsCompanion(state: Value('queued')));
  });
}
