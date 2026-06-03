import 'package:flutter_test/flutter_test.dart';
import 'package:maxim_messenger/data/max/snapshot.dart';

void main() {
  group('parseLoginSnapshot', () {
    test('не-map даёт пустой снэпшот', () {
      expect(parseLoginSnapshot(null).isEmpty, isTrue);
      expect(parseLoginSnapshot(42).isEmpty, isTrue);
      expect(parseLoginSnapshot('x').isEmpty, isTrue);
    });

    test('профиль: id и имя', () {
      final s = parseLoginSnapshot({
        'profile': {'id': 777, 'name': 'Я'},
        'chats': <Object?>[],
      });
      expect(s.profileId, 777);
      expect(s.profileName, 'Я');
    });

    test('чаты как list с вложенным lastMessage', () {
      final s = parseLoginSnapshot({
        'chats': [
          {
            'id': 10,
            'type': 'DIALOG',
            'lastMessage': {'text': 'привет', 'time': 1700000000000},
            'newMessages': 3,
          },
          {
            'id': 20,
            'title': 'Рабочий чат',
            'type': 'CHAT',
            'membersCount': 5,
            'lastEventTime': 1700000005000,
          },
        ],
      });
      expect(s.chats.length, 2);
      final c10 = s.chats.firstWhere((c) => c.id == 10);
      expect(c10.lastMessagePreview, 'привет');
      expect(c10.lastMessageTimeMs, 1700000000000);
      expect(c10.unreadCount, 3);
      expect(c10.isGroup, isFalse);
      final c20 = s.chats.firstWhere((c) => c.id == 20);
      expect(c20.title, 'Рабочий чат');
      expect(c20.isGroup, isTrue);
      expect(c20.lastMessageTimeMs, 1700000005000);
    });

    test('чаты как map {id: obj} (WEB-формат)', () {
      final s = parseLoginSnapshot({
        'chats': {
          '100': {'chatId': 100, 'name': 'Канал', 'type': 'CHANNEL'},
        },
      });
      expect(s.chats.length, 1);
      expect(s.chats.first.id, 100);
      expect(s.chats.first.title, 'Канал');
      expect(s.chats.first.isGroup, isTrue);
    });

    test('имя собеседника в диалоге берётся из participants, себя пропускаем', () {
      final s = parseLoginSnapshot({
        'profile': {'id': 1},
        'chats': [
          {
            'id': 50,
            'type': 'DIALOG',
            'participants': [
              {'id': 1, 'name': 'Я'},
              {'id': 2, 'name': 'Пётр'},
            ],
          },
        ],
      });
      expect(s.chats.single.title, 'Пётр');
    });

    test('контакты разбираются', () {
      final s = parseLoginSnapshot({
        'contacts': [
          {'id': 5, 'name': 'Анна', 'phone': '+79991234567'},
        ],
      });
      expect(s.contacts.single.id, 5);
      expect(s.contacts.single.name, 'Анна');
      expect(s.contacts.single.phone, '+79991234567');
    });

    test('чат без id пропускается', () {
      final s = parseLoginSnapshot({
        'chats': [
          {'title': 'no id'},
          {'id': 9, 'title': 'ok'},
        ],
      });
      expect(s.chats.length, 1);
      expect(s.chats.single.id, 9);
    });
  });
}
