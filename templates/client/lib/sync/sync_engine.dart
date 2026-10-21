import '../data/app_database.dart';
import '../data/session.dart';
import 'sync_api.dart';

class SyncEngine {
  SyncEngine(this.database, this.api);
  final AppDatabase database;
  final SyncApi api;
  bool _running = false;
  bool authenticationRequired = false;
  void resetAuthentication() { authenticationRequired = false; }

  Future<String> synchronize(Session session) async {
    if (_running) { return 'Sinkronisasi sedang berjalan.'; }
    if (session.expired || authenticationRequired) {
      authenticationRequired = true;
      return 'Sesi perlu diperbarui. Login online kembali untuk melanjutkan.';
    }
    _running = true;
    var sent = 0;
    var rejected = 0;
    try {
      for (final operation in await database.pending(session.scope, DateTime.now().toUtc())) {
        try {
          final response = await api.push(session, operation.payload);
          final data = response['data'] as Map<String, dynamic>;
          if (data['draft_id'] != operation.draftId || data['server_sequence'] is! int) {
            throw const FormatException('Respons sinkronisasi tidak sesuai kontrak.');
          }
          await database.acknowledge(operation, data['server_sequence'] as int);
          sent++;
        } on ApiFailure catch (error) {
          if (error.status == 401) { authenticationRequired = true; return error.message; }
          await database.recordFailure(operation, error.message, permanent: error.permanent);
          if (!error.permanent) { return error.message; }
          rejected++;
        } catch (_) {
          await database.recordFailure(operation, 'Koneksi atau respons API bermasalah.', permanent: false);
          return 'Belum terhubung. Antrean tetap tersimpan di perangkat.';
        }
      }
      // Bounded work per run. The persisted cursor resumes on the next run.
      for (var page = 0; page < 10; page++) {
        final cursor = await database.cursor(session.scope);
        final response = await api.pull(session, cursor);
        final next = response['next_cursor'] as int;
        final rows = response['data'] as List<dynamic>;
        if (next < cursor || (response['has_more'] == true && next <= cursor)) {
          throw const FormatException('Cursor tidak maju.');
        }
        await database.applyPull(session.scope, rows, next);
        if (response['has_more'] != true) { break; }
      }
      return '$sent dikirim; $rejected ditolak. Sinkronisasi selesai.';
    } on ApiFailure catch (error) {
      if (error.status == 401) { authenticationRequired = true; }
      return error.message;
    } catch (_) {
      return 'Pull belum berhasil. Data lokal tetap tersedia; coba kembali.';
    } finally {
      _running = false;
    }
  }
}
