import 'dart:typed_data';

import '../../../core/constants.dart';
import '../raw_parsers.dart';

/// Тип server-push кадра, не являющегося новым сообщением.
enum MaxPushKind { read, deleted, reactions, transcription }

/// Типизированное server-push событие (кроме NOTIF_MESSAGE 128 — то строит
/// _parsePush в IncomingMessage). chatId и messageIds — best-effort: точные
/// схемы payload для 130/142/155 в эталонных клиентах не разобраны, поэтому
/// извлекаем консервативно и мутируем БД только при явном messageId.
class MaxPushEvent {
  const MaxPushEvent(this.kind, {this.chatId, this.messageIds = const []});

  final MaxPushKind kind;
  final int? chatId;
  final List<int> messageIds;
}

/// Классифицирует server-push по опкоду. Возвращает null для NOTIF_MESSAGE (128)
/// и неизвестных опкодов. Чистая функция — под юнит-тест.
MaxPushEvent? classifyPushEvent(int opcode, Object? decoded, Uint8List body) {
  switch (opcode) {
    case MaxOp.notifMark: // 130 — обновление прочитанности
      return MaxPushEvent(MaxPushKind.read, chatId: _chatId(decoded, body));
    case MaxOp.notifMsgDelete: // 142 — сообщение удалено
      return MaxPushEvent(
        MaxPushKind.deleted,
        chatId: _chatId(decoded, body),
        messageIds: _msgIds(decoded),
      );
    case MaxOp.notifReactions: // 155 — реакции изменились
      return MaxPushEvent(
        MaxPushKind.reactions,
        chatId: _chatId(decoded, body),
        messageIds: _msgIds(decoded),
      );
    case MaxOp.notifTranscription: // 293 — транскрипция готова
      return MaxPushEvent(
        MaxPushKind.transcription,
        chatId: _chatId(decoded, body),
        messageIds: _msgIds(decoded),
      );
    default:
      return null;
  }
}

int? _chatId(Object? decoded, Uint8List body) {
  if (decoded is Map) {
    final m = decoded.map((k, v) => MapEntry(k.toString(), v));
    final v = _toInt(m['chatId']);
    if (v != null) return v;
    final chat = m['chat'];
    if (chat is Map) {
      final cv = _toInt(chat['id']);
      if (cv != null) return cv;
    }
  }
  return RawParsers.readIntAfterKey(
    body,
    Uint8List.fromList([0xA6, ...'chatId'.codeUnits]),
  );
}

/// id сообщений берём ТОЛЬКО из декодированной карты (без байт-скана) — чтобы
/// не удалить чужое сообщение из-за неверно угаданного смещения.
List<int> _msgIds(Object? decoded) {
  if (decoded is! Map) return const [];
  final m = decoded.map((k, v) => MapEntry(k.toString(), v));
  final ids = <int>[];
  void add(int? v) {
    if (v != null && !ids.contains(v)) ids.add(v);
  }

  final list = m['messageIds'] ?? m['ids'];
  if (list is List) {
    for (final e in list) {
      add(_toInt(e));
    }
  }
  add(_toInt(m['messageId']));
  add(_toInt(m['id']));
  final msg = m['message'];
  if (msg is Map) add(_toInt(msg['id']));
  return ids;
}

int? _toInt(Object? v) {
  if (v == null || v is bool) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}
