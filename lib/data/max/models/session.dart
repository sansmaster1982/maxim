/// Активная сессия/устройство аккаунта MAX (opcode 96 SESSIONS_INFO).
class MaxSession {
  const MaxSession({
    required this.id,
    this.name,
    this.device,
    this.lastSeenMs,
    this.isCurrent = false,
  });

  final int id;
  final String? name;
  final String? device;
  final int? lastSeenMs;
  final bool isCurrent;
}

/// Разбор ответа SESSIONS_INFO. Имена полей в эталонном клиенте до конца не
/// зафиксированы — берём терпимо к вариантам. Чистая функция, под юнит-тест.
List<MaxSession> parseSessions(Object? decoded) {
  if (decoded is! Map) return const [];
  final root = decoded.map((k, v) => MapEntry(k.toString(), v));
  final arr = root['sessions'] ??
      root['items'] ??
      root['result'] ??
      root['list'] ??
      root['devices'];

  final Iterable<Object?> it;
  if (arr is List) {
    it = arr;
  } else if (arr is Map) {
    it = arr.values;
  } else {
    return const [];
  }

  final out = <MaxSession>[];
  for (final e in it) {
    if (e is! Map) continue;
    final m = e.map((k, v) => MapEntry(k.toString(), v));
    final id = _toInt(m['id'] ?? m['sessionId'] ?? m['tokenId']);
    if (id == null) continue;
    out.add(MaxSession(
      id: id,
      name: _str(m['name'] ?? m['appName'] ?? m['deviceName'] ?? m['title']),
      device: _str(m['device'] ?? m['deviceType'] ?? m['platform']),
      lastSeenMs: _toInt(
        m['lastSeen'] ?? m['lastActiveTime'] ?? m['lastActivityTime'] ?? m['time'],
      ),
      isCurrent: (m['isCurrent'] ?? m['current'] ?? false) == true,
    ));
  }
  return out;
}

int? _toInt(Object? v) {
  if (v == null || v is bool) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String? _str(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}
