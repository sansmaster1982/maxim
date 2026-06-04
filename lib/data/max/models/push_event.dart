import 'dart:typed_data';

import '../../../core/constants.dart';
import '../raw_parsers.dart';
import '../reactions.dart';

/// Тип server-push кадра, не являющегося новым сообщением (NOTIF_MESSAGE 128
/// строит _parsePush в IncomingMessage).
enum MaxPushKind { read, deleted, reactions, youReacted, transcription, typing }

/// Типизированное server-push событие. Имена полей выверены по декомпилу
/// нативного клиента (n7l/zu6/swb/kwb/mwb/xwb), а не угаданы.
class MaxPushEvent {
  const MaxPushEvent(
    this.kind, {
    this.chatId,
    this.userId,
    this.messageIds = const [],
    this.mark,
    this.unread,
    this.typingType,
    this.totalCount,
    this.reactionCounts = const {},
    this.yourReaction,
    this.mediaId,
    this.transcription,
  });

  final MaxPushKind kind;
  final int? chatId;

  /// Кто (read/typing/youReacted).
  final int? userId;

  /// Затронутые сообщения. Для delete — список; для остальных — 0..1 элемент.
  final List<int> messageIds;

  /// read (NOTIF_MARK 130): водяной знак прочитанности и счётчик непрочитанных.
  final int? mark;
  final int? unread;

  /// typing (NOTIF_TYPING 129): тип составляемого (TEXT/PHOTO/AUDIO/...).
  final String? typingType;

  /// reactions/youReacted (155/156).
  final int? totalCount;
  final Map<String, int> reactionCounts;
  final String? yourReaction;

  /// transcription (293).
  final int? mediaId;
  final String? transcription;

  /// Единственный messageId для одно-сообщенческих событий.
  int? get messageId => messageIds.isEmpty ? null : messageIds.first;
}

/// Классификация server-push по опкоду. null для NOTIF_MESSAGE (128) и
/// неизвестных. Чистая — под юнит-тест.
MaxPushEvent? classifyPushEvent(int opcode, Object? decoded, Uint8List body) {
  final m = decoded is Map
      ? decoded.map((k, v) => MapEntry(k.toString(), v))
      : const <String, Object?>{};

  switch (opcode) {
    case MaxOp.notifTyping: // 129  {chatId, userId, type}
      return MaxPushEvent(
        MaxPushKind.typing,
        chatId: _chatId(m, body),
        userId: _int(m['userId']),
        typingType: _str(m['type']),
      );
    case MaxOp.notifMark: // 130  {chatId, userId, mark, unread}
      return MaxPushEvent(
        MaxPushKind.read,
        chatId: _chatId(m, body),
        userId: _int(m['userId']),
        mark: _int(m['mark']),
        unread: _int(m['unread']),
      );
    case MaxOp.notifMsgDelete: // 142  {chat{id}, messageIds[], ttl}
      return MaxPushEvent(
        MaxPushKind.deleted,
        chatId: _chatId(m, body),
        messageIds: _longList(m['messageIds']),
      );
    case MaxOp.notifReactions: // 155  {chatId, messageId, totalCount, counters[]}
      return MaxPushEvent(
        MaxPushKind.reactions,
        chatId: _chatId(m, body),
        messageIds: _single(m['messageId']),
        totalCount: _int(m['totalCount']),
        reactionCounts: parseReactionCounters(m['counters']),
      );
    case MaxOp.notifYouReacted: // 156  {chatId, messageId, reactionInfo{...}}
      final info = m['reactionInfo'];
      final im = info is Map
          ? info.map((k, v) => MapEntry(k.toString(), v))
          : const <String, Object?>{};
      return MaxPushEvent(
        MaxPushKind.youReacted,
        chatId: _chatId(m, body),
        messageIds: _single(m['messageId']),
        totalCount: _int(im['totalCount']),
        reactionCounts: parseReactionCounters(im['counters']),
        yourReaction: _str(im['yourReaction']),
      );
    case MaxOp.notifTranscription: // 293  {chatId, messageId, mediaId, transcription}
      return MaxPushEvent(
        MaxPushKind.transcription,
        chatId: _chatId(m, body),
        messageIds: _single(m['messageId']),
        mediaId: _int(m['mediaId']),
        transcription: _str(m['transcription']),
      );
    default:
      return null;
  }
}

int? _chatId(Map<String, Object?> m, Uint8List body) {
  final v = _int(m['chatId']);
  if (v != null) return v;
  // NOTIF_MSG_DELETE кладёт чат объектом {id: ...}.
  final chat = m['chat'];
  if (chat is Map) {
    final cv = _int(chat['id']);
    if (cv != null) return cv;
  }
  return RawParsers.readIntAfterKey(
    body,
    Uint8List.fromList([0xA6, ...'chatId'.codeUnits]),
  );
}

List<int> _single(Object? v) {
  final i = _int(v);
  return i == null ? const [] : [i];
}

List<int> _longList(Object? v) {
  if (v is! List) return const [];
  final out = <int>[];
  for (final e in v) {
    final i = _int(e);
    if (i != null) out.add(i);
  }
  return out;
}

int? _int(Object? v) {
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
