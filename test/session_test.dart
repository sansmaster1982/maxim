import 'package:flutter_test/flutter_test.dart';
import 'package:maxim_messenger/data/max/models/session.dart';

void main() {
  group('parseSessions', () {
    test('список sessions с разными именами полей', () {
      final s = parseSessions({
        'sessions': [
          {
            'id': 1,
            'name': 'MAX Android',
            'deviceType': 'ANDROID',
            'lastSeen': 1700000000000,
            'isCurrent': true,
          },
          {'id': 2, 'appName': 'MAX Web', 'platform': 'WEB'},
        ],
      });
      expect(s.length, 2);
      expect(s[0].id, 1);
      expect(s[0].name, 'MAX Android');
      expect(s[0].device, 'ANDROID');
      expect(s[0].lastSeenMs, 1700000000000);
      expect(s[0].isCurrent, isTrue);
      expect(s[1].name, 'MAX Web');
      expect(s[1].device, 'WEB');
      expect(s[1].isCurrent, isFalse);
    });

    test('map-форма {id: obj}', () {
      final s = parseSessions({
        'sessions': {
          '9': {'sessionId': 9, 'name': 'X'},
        },
      });
      expect(s.single.id, 9);
    });

    test('сессия без id пропускается', () {
      final s = parseSessions({
        'sessions': [
          {'name': 'no id'},
          {'id': 3},
        ],
      });
      expect(s.length, 1);
      expect(s.single.id, 3);
    });

    test('не-map -> пусто', () {
      expect(parseSessions(null), isEmpty);
      expect(parseSessions('x'), isEmpty);
    });
  });
}
