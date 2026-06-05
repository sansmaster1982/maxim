import 'contact_name.dart';
import 'models/chat.dart';
import 'models/contact.dart';

/// Разобранный снэпшот ответа LOGIN (opcode 19 при `interactive=true`).
/// Сервер кладёт сюда профиль, список чатов и контакты — то, чем наполняется
/// главный экран сразу после входа, без отдельных запросов.
class LoginSnapshot {
  const LoginSnapshot({
    this.profileId,
    this.profileName,
    this.chats = const [],
    this.contacts = const [],
  });

  final int? profileId;
  final String? profileName;
  final List<MaxChat> chats;
  final List<MaxContact> contacts;

  bool get isEmpty =>
      profileId == null && chats.isEmpty && contacts.isEmpty;
}

/// Разбор снэпшота LOGIN. Порт `extract_chats`/`_peer_name` из проверенного
/// `web_demo/bridge.py`. Терпим к вариантам формата: `chats`/`contacts`
/// приходят как list ЛИБО как map `{id: obj}`; имена полей различаются между
/// ANDROID и WEB. Функция чистая (без сети и БД) — покрыта `snapshot_test`.
LoginSnapshot parseLoginSnapshot(Object? decoded) {
  if (decoded is! Map) return const LoginSnapshot();
  final root = decoded.map((k, v) => MapEntry(k.toString(), v));

  int? profileId;
  String? profileName;
  final profile = root['profile'];
  if (profile is Map) {
    final pm = profile.map((k, v) => MapEntry(k.toString(), v));
    profileId = _toInt(pm['id'] ?? pm['userId'] ?? pm['contactId']);
    profileName = displayContactName(pm) ?? _str(pm['firstName']);
  }

  final chats = _parseChats(
    _asMapList(
      root['chats'] ?? root['chatList'] ?? root['items'] ?? root['dialogs'],
    ),
    profileId,
  );
  final contacts = _parseContacts(
    _asMapList(root['contacts'] ?? root['contactList']),
  );

  return LoginSnapshot(
    profileId: profileId,
    profileName: profileName,
    chats: chats,
    contacts: contacts,
  );
}

List<MaxChat> _parseChats(List<Map<String, Object?>> arr, int? selfId) {
  final out = <MaxChat>[];
  for (final c in arr) {
    final id = _toInt(c['id'] ?? c['chatId'] ?? c['cid']);
    if (id == null) continue;

    final last = c['lastMessage'] ?? c['message'] ?? c['lastMsg'];
    String? lastText;
    int? lastTime;
    if (last is Map) {
      final lm = last.map((k, v) => MapEntry(k.toString(), v));
      lastText = _str(lm['text']);
      lastTime = _toInt(lm['time']);
    }
    lastTime ??= _toInt(c['lastEventTime'] ?? c['modified'] ?? c['lastFireTime']);

    final type = (c['type'] ?? c['chatType'] ?? '').toString().toLowerCase();
    final members = _toInt(c['membersCount'] ?? c['participantsCount']) ?? 0;
    final isGroup = type == 'chat' ||
        type == 'channel' ||
        type.contains('group') ||
        members > 2;

    final title =
        _str(c['title']) ?? displayContactName(c) ?? _peerName(c, selfId);
    final avatar = _str(
      c['baseIconUrl'] ?? c['iconUrl'] ?? c['avatar'] ?? c['photo'] ??
          c['baseRawIconUrl'],
    );
    final unread =
        _toInt(c['newMessages'] ?? c['unread'] ?? c['unreadCount']) ?? 0;

    out.add(MaxChat(
      id: id,
      title: title,
      avatarUrl: avatar,
      isGroup: isGroup,
      lastMessageTimeMs: lastTime,
      lastMessagePreview: lastText,
      unreadCount: unread,
    ));
  }
  return out;
}

List<MaxContact> _parseContacts(List<Map<String, Object?>> arr) {
  final out = <MaxContact>[];
  for (final c in arr) {
    final id = _toInt(c['id'] ?? c['contactId'] ?? c['userId']);
    if (id == null) continue;
    final name = displayContactName(c) ?? _str(c['firstName']);
    final phone = _str(c['phone']);
    final avatar =
        _str(c['baseRawUrl'] ?? c['photo'] ?? c['avatar'] ?? c['baseIconUrl']);
    out.add(MaxContact(id: id, name: name, phone: phone, avatarUrl: avatar));
  }
  return out;
}

/// Имя собеседника для диалога 1:1, когда у чата нет своего title. Ищет в
/// participants/members/users, пропуская самого себя ([selfId]).
String? _peerName(Map<String, Object?> chat, int? selfId) {
  for (final key in const ['participants', 'members', 'users']) {
    final v = chat[key];
    final people = <Map<String, Object?>>[];
    if (v is List) {
      for (final p in v) {
        if (p is Map) people.add(p.map((k, val) => MapEntry(k.toString(), val)));
      }
    } else if (v is Map) {
      v.forEach((_, val) {
        if (val is Map) {
          people.add(val.map((k, vv) => MapEntry(k.toString(), vv)));
        }
      });
    }
    for (final p in people) {
      final pid = _toInt(p['id'] ?? p['userId'] ?? p['contactId']);
      if (selfId != null && pid == selfId) continue;
      final nm = displayContactName(p) ?? _str(p['firstName']);
      if (nm != null) return nm;
    }
  }
  return null;
}

int? _toInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String? _str(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

/// Превращает list ИЛИ map-значения в список map'ов со строковыми ключами.
List<Map<String, Object?>> _asMapList(Object? v) {
  final Iterable<Object?> it;
  if (v is List) {
    it = v;
  } else if (v is Map) {
    it = v.values;
  } else {
    return const [];
  }
  return it
      .whereType<Map>()
      .map((m) => m.map((k, val) => MapEntry(k.toString(), val)))
      .toList();
}
