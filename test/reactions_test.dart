import 'package:flutter_test/flutter_test.dart';
import 'package:maxim_messenger/data/max/reactions.dart';

void main() {
  group('reactions wire-format', () {
    test('set payload (op 178): вложенный reaction{reactionType,id}', () {
      expect(reactionSetPayload(10, 77, '👍'), {
        'chatId': 10,
        'messageId': 77,
        'reaction': {'reactionType': 'EMOJI', 'id': '👍'},
      });
    });

    test('cancel payload (op 179): только chatId/messageId', () {
      expect(reactionCancelPayload(10, 77), {'chatId': 10, 'messageId': 77});
    });

    test('parseReactionCounters: counters -> {emoji: count}', () {
      expect(
        parseReactionCounters([
          {'reaction': '👍', 'count': 3},
          {'reaction': '❤️', 'count': 1},
        ]),
        {'👍': 3, '❤️': 1},
      );
    });

    test('parseReactionCounters: мусор/пусто', () {
      expect(parseReactionCounters(null), isEmpty);
      expect(parseReactionCounters('x'), isEmpty);
      expect(parseReactionCounters([
        {'count': 3}, // нет reaction
      ]), isEmpty);
    });
  });
}
