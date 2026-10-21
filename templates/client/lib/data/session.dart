class Session {
  const Session({required this.origin, required this.userId, required this.name,
    required this.token, required this.expiresAt, required this.deviceId});
  final String origin;
  final int userId;
  final String name;
  final String token;
  final DateTime expiresAt;
  final String deviceId;
  String get scope => '$origin|$userId';
  bool get expired => !DateTime.now().toUtc().isBefore(expiresAt);
  Map<String, dynamic> toJson() => {'origin': origin, 'user_id': userId, 'name': name,
    'token': token, 'expires_at': expiresAt.toIso8601String(), 'device_id': deviceId};
  factory Session.fromJson(Map<String, dynamic> data) => Session(
    origin: data['origin'] as String, userId: data['user_id'] as int,
    name: data['name'] as String, token: data['token'] as String,
    expiresAt: DateTime.parse(data['expires_at'] as String), deviceId: data['device_id'] as String);
}
