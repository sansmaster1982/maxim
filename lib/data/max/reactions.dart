// Помощники для реакций MAX. Wire-формат подтверждён тремя источниками:
// декомпил нативного клиента (kgb.java/kfb.java), nyakokitsu/MaxProtoExplanation
// и nsdkinx/vkmax. Чистые функции — под юнит-тест.

/// Payload для MSG_REACTION (opcode 178): поставить реакцию-эмодзи на сообщение.
/// reaction — вложенный объект {reactionType, id}; reactionType строкой "EMOJI",
/// id — сам символ эмодзи.
Map<String, Object?> reactionSetPayload(int chatId, int messageId, String emoji) {
  return {
    'chatId': chatId,
    'messageId': messageId,
    'reaction': {'reactionType': 'EMOJI', 'id': emoji},
  };
}

/// Payload для MSG_CANCEL_REACTION (opcode 179): снять свою реакцию.
Map<String, Object?> reactionCancelPayload(int chatId, int messageId) {
  return {'chatId': chatId, 'messageId': messageId};
}

/// counters сервера: `[{reaction: "👍", count: 3}, ...]` -> `{"👍": 3}`.
/// На стороне сервер->клиент reaction приходит ГОЛОЙ строкой-эмодзи
/// (декомпил u7l.b), а не объектом {reactionType,id}, как в запросе.
Map<String, int> parseReactionCounters(Object? counters) {
  final out = <String, int>{};
  if (counters is! List) return out;
  for (final e in counters) {
    if (e is! Map) continue;
    final m = e.map((k, v) => MapEntry(k.toString(), v));
    final r = (m['reaction'] ?? m['id'])?.toString();
    final count = _toInt(m['count']);
    if (r != null && r.isNotEmpty && count != null) out[r] = count;
  }
  return out;
}

int? _toInt(Object? v) {
  if (v == null || v is bool) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}
