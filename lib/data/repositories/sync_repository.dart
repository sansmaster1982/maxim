import 'package:logger/logger.dart';

import '../local/database.dart';
import '../local/secure_storage.dart';
import '../max/max_client.dart';
import '../max/snapshot.dart';

/// Применяет снэпшот ответа LOGIN к локальной БД: профиль (myUserId), чаты,
/// контакты. Вызывается один раз после успешного входа — после этого главный
/// экран читает уже наполненные чаты из БД.
class SyncRepository {
  SyncRepository({
    required this.client,
    required this.db,
    required this.storage,
    Logger? logger,
  }) : _log = logger ?? Logger();

  final MaxClient client;
  final AppDatabase db;
  final SecureStorage storage;
  final Logger _log;

  /// Разбирает кешированный снэпшот логина и пишет его в БД.
  /// Возвращает число записанных чатов. Не бросает: ошибка синхронизации не
  /// должна валить уже состоявшийся вход.
  Future<int> applyLoginSnapshot() async {
    final snap = parseLoginSnapshot(client.lastLoginSnapshot);
    if (snap.isEmpty) {
      _log.w('login snapshot пуст — чаты не из чего наполнить '
          '(interactive=false или сервер не прислал)');
      return 0;
    }

    if (snap.profileId != null) {
      await storage.writeMyUserId(snap.profileId!);
    }

    for (final c in snap.contacts) {
      try {
        await db.upsertContact(c);
      } catch (e) {
        _log.w('upsert contact ${c.id} failed: $e');
      }
    }

    var written = 0;
    for (final c in snap.chats) {
      try {
        final existing = await db.chat(c.id);
        if (existing == null) {
          await db.upsertChat(c);
        } else {
          // Сохраняем локальные флаги (pin/archive/mute), обновляем контент.
          await db.upsertChat(existing.copyWith(
            title: c.title ?? existing.title,
            avatarUrl: c.avatarUrl ?? existing.avatarUrl,
            isGroup: c.isGroup,
            lastMessageTimeMs: c.lastMessageTimeMs ?? existing.lastMessageTimeMs,
            lastMessagePreview:
                c.lastMessagePreview ?? existing.lastMessagePreview,
            unreadCount: c.unreadCount,
          ));
        }
        written++;
      } catch (e) {
        _log.w('upsert chat ${c.id} failed: $e');
      }
    }

    _log.i('login snapshot применён: чатов=$written, контактов=${snap.contacts.length}');
    return written;
  }
}
