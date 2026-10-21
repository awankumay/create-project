import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/session.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.status, this.message);
  final int status;
  final String message;
  bool get permanent => status >= 400 && status < 500 && ![401, 408, 429].contains(status);
  @override
  String toString() => message;
}

class SyncApi {
  SyncApi(this.client);
  final http.Client client;
  static const timeout = Duration(seconds: 12);

  static String normalizeOrigin(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment || (uri.path != '' && uri.path != '/')) {
      throw ArgumentError('Gunakan origin API, contoh https://erp.example.com atau http://10.0.2.2:8000');
    }
    return uri.origin;
  }

  Map<String, dynamic> decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Do not persist raw response bodies: they may contain framework debug data.
      final message = switch (response.statusCode) {
        401 => 'Sesi ditolak server. Login kembali; antrean tetap tersimpan.',
        403 => 'Akses ditolak server.',
        409 => 'Konflik ID atau idempotency. Perlu ditinjau.',
        422 => 'Data atau kredensial tidak valid.',
        429 => 'Terlalu banyak permintaan. Akan dicoba kembali.',
        _ => 'Server belum tersedia (HTTP ${response.statusCode}).',
      };
      throw ApiFailure(response.statusCode, message);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Session> login(String origin, String email, String password, String deviceId) async {
    origin = normalizeOrigin(origin);
    final response = await client.post(Uri.parse('$origin/api/v1/auth/login'),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password, 'device_name': 'flutter-$deviceId'})).timeout(timeout);
    final data = decode(response);
    final user = data['user'] as Map<String, dynamic>;
    return Session(origin: origin, userId: user['id'] as int, name: user['name'] as String,
      token: data['token'] as String, expiresAt: DateTime.parse(data['expires_at'] as String), deviceId: deviceId);
  }

  Map<String, String> headers(Session session) => {'Accept': 'application/json',
    'Content-Type': 'application/json', 'Authorization': 'Bearer ${session.token}'};

  Future<Map<String, dynamic>> push(Session session, String payload) async {
    return decode(await client.post(Uri.parse('${session.origin}/api/v1/sync/drafts'),
      headers: headers(session), body: payload).timeout(timeout));
  }

  Future<Map<String, dynamic>> pull(Session session, int cursor) async {
    return decode(await client.get(Uri.parse('${session.origin}/api/v1/sync/drafts?cursor=$cursor'),
      headers: headers(session)).timeout(timeout));
  }

  Future<void> logout(Session session) async {
    final response = await client.delete(Uri.parse('${session.origin}/api/v1/auth/session'),
      headers: headers(session)).timeout(timeout);
    if (response.statusCode != 204 && response.statusCode != 401) {
      throw ApiFailure(response.statusCode, 'Tidak dapat mencabut sesi server.');
    }
  }
}
