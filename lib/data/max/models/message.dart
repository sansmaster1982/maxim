import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'attach.dart';

enum MessageDirection { incoming, outgoing }

enum MessageStatus { pending, sent, delivered, read, failed, rejected }

class MaxMessage extends Equatable {
  final int? id;
  final int chatId;
  final int? senderId;
  final String text;
  final int timeMs;
  final MessageDirection direction;
  final MessageStatus status;

  /// Локальный id, который пригодится пока сервер не вернул свой.
  final String? localId;

  /// id сообщения, на которое отвечаем (если это reply).
  final int? replyToId;

  /// Короткий превью-текст того сообщения, чтобы рисовать в пузыре без
  /// дополнительного запроса в БД.
  final String? replyToPreview;

  /// Вложения сообщения. Хранятся в отдельной таблице `attachments`,
  /// подгружаются репозиторием. В `toMap`/`fromDbRow` НЕ участвуют.
  final List<MaxAttach> attaches;

  /// Метка времени последней правки (opcode 67). null = сообщение не редактировалось.
  final int? editedAtMs;

  /// Реакции на сообщение: {эмодзи: количество}. Приходят push 155/156.
  final Map<String, int> reactions;

  /// Собственная реакция текущего пользователя (эмодзи) или null.
  final String? yourReaction;

  const MaxMessage({
    required this.chatId,
    required this.text,
    required this.timeMs,
    required this.direction,
    this.id,
    this.senderId,
    this.status = MessageStatus.sent,
    this.localId,
    this.replyToId,
    this.replyToPreview,
    this.attaches = const [],
    this.editedAtMs,
    this.reactions = const {},
    this.yourReaction,
  });

  MaxMessage copyWith({
    int? id,
    MessageStatus? status,
    String? text,
    int? timeMs,
    int? replyToId,
    String? replyToPreview,
    List<MaxAttach>? attaches,
    int? editedAtMs,
    Map<String, int>? reactions,
    String? yourReaction,
  }) {
    return MaxMessage(
      id: id ?? this.id,
      chatId: chatId,
      senderId: senderId,
      text: text ?? this.text,
      timeMs: timeMs ?? this.timeMs,
      direction: direction,
      status: status ?? this.status,
      localId: localId,
      replyToId: replyToId ?? this.replyToId,
      replyToPreview: replyToPreview ?? this.replyToPreview,
      attaches: attaches ?? this.attaches,
      editedAtMs: editedAtMs ?? this.editedAtMs,
      reactions: reactions ?? this.reactions,
      yourReaction: yourReaction ?? this.yourReaction,
    );
  }

  bool get hasAttaches => attaches.isNotEmpty;
  bool get hasReactions => reactions.isNotEmpty;

  Map<String, Object?> toMap() => {
    'id': id,
    'local_id': localId,
    'chat_id': chatId,
    'sender_id': senderId,
    'text': text,
    'time_ms': timeMs,
    'direction': direction.name,
    'status': status.name,
    'reply_to_id': replyToId,
    'reply_to_preview': replyToPreview,
    'edited_at': editedAtMs,
    'reactions': reactions.isEmpty ? null : jsonEncode(reactions),
    'your_reaction': yourReaction,
  };

  factory MaxMessage.fromDbRow(Map<String, Object?> r) => MaxMessage(
    id: r['id'] as int?,
    localId: r['local_id'] as String?,
    chatId: r['chat_id'] as int,
    senderId: r['sender_id'] as int?,
    text: (r['text'] as String?) ?? '',
    timeMs: (r['time_ms'] as int?) ?? 0,
    direction: MessageDirection.values.firstWhere(
      (d) => d.name == (r['direction'] as String?),
      orElse: () => MessageDirection.incoming,
    ),
    status: MessageStatus.values.firstWhere(
      (s) => s.name == (r['status'] as String?),
      orElse: () => MessageStatus.sent,
    ),
    replyToId: r['reply_to_id'] as int?,
    replyToPreview: r['reply_to_preview'] as String?,
    editedAtMs: (r['edited_at'] as num?)?.toInt(),
    reactions: _decodeReactions(r['reactions'] as String?),
    yourReaction: r['your_reaction'] as String?,
  );

  static Map<String, int> _decodeReactions(String? s) {
    if (s == null || s.isEmpty) return const {};
    try {
      final m = jsonDecode(s);
      if (m is Map) {
        return m.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
    } catch (_) {}
    return const {};
  }

  @override
  List<Object?> get props => [
    id,
    localId,
    chatId,
    senderId,
    text,
    timeMs,
    direction,
    status,
    replyToId,
    replyToPreview,
    attaches,
    editedAtMs,
    reactions,
    yourReaction,
  ];
}
