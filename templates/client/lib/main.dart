import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'data/app_database.dart';
import 'data/session.dart';
import 'sync/sync_api.dart';
import 'sync/sync_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final folder = await getApplicationSupportDirectory();
    final database = AppDatabase(NativeDatabase.createInBackground(File(path.join(folder.path, 'offline-drafts.sqlite'))));
    const storage = FlutterSecureStorage();
    final client = http.Client();
    final state = AppState(database, storage, SyncApi(client));
    await state.restore();
    runApp(StarterApp(state: state));
  } catch (_) {
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Penyimpanan lokal tidak dapat dibuka. Periksa konfigurasi perangkat.')))));
  }
}

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState(this.database, this.storage, this.api) {
    engine = SyncEngine(database, api);
    WidgetsBinding.instance.addObserver(this);
  }
  final AppDatabase database;
  final FlutterSecureStorage storage;
  final SyncApi api;
  late final SyncEngine engine;
  Session? session;
  String deviceId = '';
  String message = 'Data operasional dibaca dari penyimpanan lokal.';
  bool busy = false;
  Timer? timer;

  Future<void> restore() async {
    deviceId = await storage.read(key: 'device_id') ?? const Uuid().v4();
    await storage.write(key: 'device_id', value: deviceId);
    final saved = await storage.read(key: 'session');
    if (saved != null) session = Session.fromJson(jsonDecode(saved) as Map<String, dynamic>);
    startTimer();
  }

  void startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 20), (_) => unawaited(sync()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) { startTimer(); unawaited(sync()); }
    else { timer?.cancel(); }
  }

  Future<void> login(String origin, String email, String password) async {
    if (busy) return;
    busy = true; notifyListeners();
    try {
      final authenticated = await api.login(origin, email, password, deviceId);
      await storage.write(key: 'session', value: jsonEncode(authenticated.toJson()));
      session = authenticated;
      engine.resetAuthentication();
      message = 'Login berhasil. Draft dapat disimpan offline sampai sesi kedaluwarsa.';
    } on ApiFailure catch (error) { message = error.message; }
    catch (_) { message = 'Login gagal. Periksa alamat API, jaringan, dan penyimpanan aman.'; }
    finally { busy = false; notifyListeners(); }
  }

  Future<void> save(String title, String notes) async {
    final owner = session;
    if (owner == null || owner.expired || engine.authenticationRequired) throw StateError('Login online kembali sebelum membuat draft.');
    await database.createDraft(scope: owner.scope, deviceId: deviceId, title: title, notes: notes.isEmpty ? null : notes);
    message = 'Tersimpan di perangkat.'; notifyListeners();
    unawaited(sync());
  }

  Future<void> sync() async {
    final owner = session;
    if (busy || owner == null) return;
    busy = true; notifyListeners();
    try { message = await engine.synchronize(owner); }
    catch (_) { message = 'Sinkronisasi gagal; antrean lokal tetap tersimpan.'; }
    finally { busy = false; notifyListeners(); }
  }

  Future<void> retryRejected() async {
    if (busy || session == null) return;
    await database.retryRejected(session!.scope);
    await sync();
  }

  Future<void> logout() async {
    final owner = session;
    if (busy || owner == null) return;
    busy = true; notifyListeners();
    var revoked = true;
    try { await api.logout(owner); } catch (_) { revoked = false; }
    try {
      await storage.delete(key: 'session');
      session = null;
      message = revoked ? 'Logout berhasil. Draft lokal tetap tersimpan per akun.'
        : 'Logout lokal selesai. Token server belum dicabut dan akan kedaluwarsa; cabut di server bila diperlukan.';
    } catch (_) { message = 'Token lokal belum dapat dihapus. Coba logout kembali.'; }
    finally { busy = false; notifyListeners(); }
  }

  @override
  void dispose() {
    timer?.cancel(); WidgetsBinding.instance.removeObserver(this);
    api.client.close(); unawaited(database.close()); super.dispose();
  }
}

class StarterApp extends StatelessWidget {
  const StarterApp({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Offline Draft Starter',
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: ListenableBuilder(listenable: state, builder: (context, _) => state.session == null
      ? LoginPage(state: state) : DraftPage(state: state)),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.state});
  final AppState state;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final origin = TextEditingController(text: Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000');
  final email = TextEditingController();
  final password = TextEditingController();
  @override
  void dispose() { origin.dispose(); email.dispose(); password.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Masuk ke server Laravel')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
      child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Login pertama membutuhkan koneksi. Setelah itu, draft tersimpan di perangkat.'),
          const SizedBox(height: 20),
          TextField(controller: origin, decoration: const InputDecoration(labelText: 'Alamat server / origin API')),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 20),
          FilledButton(onPressed: widget.state.busy ? null : () async {
            final value = password.text;
            password.clear();
            await widget.state.login(origin.text, email.text, value);
          }, child: const Text('Masuk')),
          const SizedBox(height: 16), Text(widget.state.message),
        ],
      )),
    )),
  );
}

class DraftPage extends StatefulWidget {
  const DraftPage({super.key, required this.state});
  final AppState state;
  @override
  State<DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<DraftPage> {
  final title = TextEditingController();
  final notes = TextEditingController();
  bool saving = false;
  @override
  void dispose() { title.dispose(); notes.dispose(); super.dispose(); }

  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await widget.state.save(title.text, notes.text);
      title.clear(); notes.clear();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan. Periksa isian, sesi, dan ruang penyimpanan.')));
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final owner = state.session!;
    return Scaffold(
      appBar: AppBar(title: const Text('Draft Offline'), actions: [
        IconButton(tooltip: 'Sinkronkan', onPressed: state.busy ? null : state.sync, icon: const Icon(Icons.sync)),
        IconButton(tooltip: 'Logout / ganti akun', onPressed: state.busy || saving ? null : state.logout, icon: const Icon(Icons.logout)),
      ]),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000),
        child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${owner.name} • ${owner.origin}'),
          Text(state.message),
          if (owner.expired || state.engine.authenticationRequired) const Text('Sesi kedaluwarsa. Logout lalu login online kembali.'),
          if (state.busy) const LinearProgressIndicator(),
          TextField(controller: title, maxLength: 120, decoration: const InputDecoration(labelText: 'Judul draft')),
          TextField(controller: notes, maxLength: 2000, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Catatan')),
          Wrap(spacing: 12, children: [
            FilledButton.icon(onPressed: saving || owner.expired || state.engine.authenticationRequired ? null : save, icon: const Icon(Icons.save), label: const Text('Simpan di perangkat')),
            TextButton(onPressed: state.busy ? null : state.retryRejected, child: const Text('Coba ulang draft ditolak')),
          ]),
          const Divider(),
          Expanded(child: StreamBuilder<List<Draft>>(
            stream: state.database.watchDrafts(owner.scope),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Text('Database lokal belum dapat dibaca.');
              final rows = snapshot.data ?? [];
              if (rows.isEmpty) return const Center(child: Text('Belum ada draft. Coba simpan saat server tidak tersambung.'));
              return ListView.builder(itemCount: rows.length, itemBuilder: (context, index) {
                final row = rows[index];
                final label = switch (row.state) {
                  'synced' => 'Tersinkronisasi', 'rejected' => 'Ditolak server — perlu ditinjau', _ => 'Menunggu sinkronisasi',
                };
                return ListTile(title: Text(row.title), subtitle: Text('${row.notes ?? ''}\n$label'),
                  trailing: Icon(row.state == 'synced' ? Icons.cloud_done : row.state == 'rejected' ? Icons.error_outline : Icons.cloud_upload_outlined));
              });
            },
          )),
        ])),
      )),
    );
  }
}
