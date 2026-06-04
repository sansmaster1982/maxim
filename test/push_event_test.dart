import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxim_messenger/data/max/models/push_event.dart';

void main() {
  final empty = Uint8List(0);

  group('classifyPushEvent', () {
    test('128 NOTIF_MESSAGE -> null (его строит _parsePush)', () {
      expect(classifyPushEvent(128, {'chatId': 1}, empty), isNull);
    });

    test('неизвестный опкод -> null', () {
      expect(classifyPushEvent(64, {'chatId': 1}, empty), isNull);
    });

    test('129 typing: chatId/userId/type', () {
      final e =
          classifyPushEvent(129, {'chatId': 1, 'userId': 2, 'type': 'TEXT'}, empty)!;
      expect(e.kind, MaxPushKind.typing);
      expect(e.chatId, 1);
      expect(e.userId, 2);
      expect(e.typingType, 'TEXT');
    });

    test('130 read: chatId/userId/mark/unread', () {
      final e = classifyPushEvent(
          130, {'chatId': 1, 'userId': 2, 'mark': 1700, 'unread': 5}, empty)!;
      expect(e.kind, MaxPushKind.read);
      expect(e.mark, 1700);
      expect(e.unread, 5);
    });

    test('142 delete: chat{id} + messageIds[]', () {
      final e = classifyPushEvent(142, {
        'chat': {'id': 9},
        'messageIds': [1, 2, 3],
      }, empty)!;
      expect(e.kind, MaxPushKind.deleted);
      expect(e.chatId, 9);
      expect(e.messageIds, [1, 2, 3]);
    });

    test('155 reactions: counters -> map', () {
      final e = classifyPushEvent(155, {
        'chatId': 1,
        'messageId': 77,
        'totalCount': 4,
        'counters': [
          {'reaction': '👍', 'count': 3},
          {'reaction': '❤️', 'count': 1},
        ],
      }, empty)!;
      expect(e.kind, MaxPushKind.reactions);
      expect(e.messageId, 77);
      expect(e.totalCount, 4);
      expect(e.reactionCounts, {'👍': 3, '❤️': 1});
    });

    test('156 youReacted: reactionInfo{counters,totalCount,yourReaction}', () {
      final e = classifyPushEvent(156, {
        'chatId': 1,
        'messageId': 77,
        'reactionInfo': {
          'totalCount': 2,
          'counters': [
            {'reaction': '👍', 'count': 2},
          ],
          'yourReaction': '👍',
        },
      }, empty)!;
      expect(e.kind, MaxPushKind.youReacted);
      expect(e.yourReaction, '👍');
      expect(e.reactionCounts, {'👍': 2});
    });

    test('293 transcription: mediaId + transcription', () {
      final e = classifyPushEvent(293, {
        'chatId': 1,
        'messageId': 77,
        'mediaId': 555,
        'transcription': 'привет',
      }, empty)!;
      expect(e.kind, MaxPushKind.transcription);
      expect(e.mediaId, 555);
      expect(e.transcription, 'привет');
    });

    test('chatId байт-скан fallback (142 без chat в декоде)', () {
      final body =
          Uint8List.fromList([0xA6, ...'chatId'.codeUnits, 0xD2, 0, 0, 0, 5]);
      final e = classifyPushEvent(142, null, body)!;
      expect(e.chatId, 5);
    });
  });
}
