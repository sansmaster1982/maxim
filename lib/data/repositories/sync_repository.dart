import 'package:logger/logger.dart';

import '../local/database.dart';
import '../local/secure_storage.dart';
import '../max/max_client.dart';
import '../max/models/chat.dart';
import '../max/raw_parsers.dart';
import '../max/snapshot.dart';
import 'chats_repository.dart';

/// Применяет снэпшот ответа LOGIN к локальной БД: профиль (myUserId), чаты,
/// контакты. Вызывается один раз после входа — затем главный экран читает уже
/// наполненную БД.
///
/// Наполнение чатов двухуровневое (как в maxclient):
///   1. Богатые объекты из декодированного снэпшота (title, превью, unread).
///   2. id чатов, добытые байт-сканом сырого тела (ловит чаты, которые
///      compact-msgpack не отдал декодеру) → детали через CHAT_INFO (op 48).
class SyncRepository {
  SyncRepository({
    required this.client,
    required this.db,
    required this.storage,
    required this.chats,
    Logger? logger,
  }) : _log = logger ?? Logger();

  final MaxClient client;
  final AppDatabase db;
  final SecureStorage storage;
  final ChatsRepository chats;
  final Logger _log;

  /// Разбирает кешированный снэпшот логина и пишет его в БД. Возвращает число
  /// затронутых чатов. Не бросает: ошибка синка не валит состоявшийся вход.
  Future<int> applyLoginSnapshot() async {
    final snap = parseLoginSnapshot(client.lastLoginSnapshot);
    final raw = client.lastLoginRaw;

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

    // 1. Богатые чаты из декода.
    final richById = {for (final c in snap.chats) c.id: c};
    // 2. id из байт-скана сырого тела (fallback для compact-кодирования).
    final scanned = raw == null ? const <int>[] : RawParsers.extractChatIds(raw);
    final allIds = <int>{...richById.keys, ...scanned};

    if (allIds.isEmpty) {
      _log.w('login snapshot пуст: ни декода чатов, ни id в raw '
          '(interactive=false или сервер не прислал)');
      return 0;
    }

    for (final id in allIds) {
      try {
        final rich = richById[id];
        if (rich != null) {
          await _mergeUpsert(rich);
        } else if (await db.chat(id) == null) {
          // Чат найден только байт-сканом — ставим заглушку, title добьём ниже.
          await db.upsertChat(MaxChat(id: id));
        }
      } catch (e) {
        _log.w('upsert chat $id failed: $e');
      }
    }

    // Чаты без названия (декод не дал title либо это заглушки) — детали через
    // CHAT_INFO. ChatsRepository.refresh сам мёржит, не затирая существующее.
    final needInfo =
        allIds.where((id) => (richById[id]?.title ?? '').isEmpty).toList();
    if (needInfo.isNotEmpty) {
      try {
        await chats.refresh(needInfo);
      } catch (e) {
        _log.w('CHAT_INFO для ${needInfo.length} чатов не удался: $e');
      }
    }

    _log.i('login snapshot применён: чатов=${allIds.length} '
        '(декод ${richById.length}, байт-скан ${scanned.length}), '
        'контактов=${snap.contacts.length}');
    return allIds.length;
  }

  Future<void> _mergeUpsert(MaxChat c) async {
    final existing = await db.chat(c.id);
    if (existing == null) {
      await db.upsertChat(c);
      return;
    }
    // Сохраняем локальные флаги (pin/archive/mute), обновляем контент.
    await db.upsertChat(existing.copyWith(
      title: c.title ?? existing.title,
      avatarUrl: c.avatarUrl ?? existing.avatarUrl,
      isGroup: c.isGroup,
      lastMessageTimeMs: c.lastMessageTimeMs ?? existing.lastMessageTimeMs,
      lastMessagePreview: c.lastMessagePreview ?? existing.lastMessagePreview,
      unreadCount: c.unreadCount,
    ));
  }
}
