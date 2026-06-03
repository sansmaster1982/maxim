import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxim_messenger/data/max/models/push_event.dart';

void main() {
  group('classifyPushEvent', () {
    final empty = Uint8List(0);

    test('128 NOTIF_MESSAGE -> null (его строит _parsePush)', () {
      expect(
        classifyPushEvent(128, {
          'chatId': 1,
          'message': {'id': 5},
        }, empty),
        isNull,
      );
    });

    test('142 delete: chatId + одиночный messageId', () {
      final ev = classifyPushEvent(142, {'chatId': 10, 'messageId': 777}, empty);
      expect(ev, isNotNull);
      expect(ev!.kind, MaxPushKind.deleted);
      expect(ev.chatId, 10);
      expect(ev.messageIds, [777]);
    });

    test('142 delete: список messageIds', () {
      final ev = classifyPushEvent(142, {
        'chatId': 10,
        'messageIds': [1, 2, 3],
      }, empty);
      expect(ev!.messageIds, [1, 2, 3]);
    });

    test('130 read: chatId, messageIds пуст', () {
      final ev = classifyPushEvent(130, {'chatId': 42}, empty);
      expect(ev!.kind, MaxPushKind.read);
      expect(ev.chatId, 42);
      expect(ev.messageIds, isEmpty);
    });

    test('293 transcription: id из вложенного message', () {
      final ev = classifyPushEvent(293, {
        'chatId': 7,
        'message': {'id': 99},
      }, empty);
      expect(ev!.kind, MaxPushKind.transcription);
      expect(ev.chatId, 7);
      expect(ev.messageIds, [99]);
    });

    test('неизвестный опкод -> null', () {
      expect(classifyPushEvent(64, {'chatId': 1}, empty), isNull);
    });

    test('chatId из байт-скана, если нет в декоде', () {
      // \xA6chatId \xD2 <int32 = 5>
      final body =
          Uint8List.fromList([0xA6, ...'chatId'.codeUnits, 0xD2, 0, 0, 0, 5]);
      final ev = classifyPushEvent(142, null, body);
      expect(ev!.chatId, 5);
      expect(ev.messageIds, isEmpty);
    });
  });
}
