import 'package:flutter_test/flutter_test.dart';
import 'package:maxim_messenger/data/max/contact_name.dart';

void main() {
  group('displayContactName', () {
    test('плоское поле name имеет приоритет', () {
      expect(displayContactName({'name': 'Анна'}), 'Анна');
    });

    test('массив names: CUSTOM выигрывает у ONEME', () {
      final m = {
        'names': [
          {'name': 'Я', 'firstName': 'Я', 'type': 'CUSTOM'},
          {
            'name': 'Александр',
            'firstName': 'Александр',
            'lastName': 'Бронников',
            'type': 'ONEME',
          },
        ],
      };
      expect(displayContactName(m), 'Я');
    });

    test('массив names: один ONEME — берём его', () {
      final m = {
        'names': [
          {
            'firstName': 'Александр',
            'lastName': 'Бронников',
            'type': 'ONEME',
          },
        ],
      };
      // name пустой → собираем firstName + lastName
      expect(displayContactName(m), 'Александр Бронников');
    });

    test('массив names без типов — берём первый', () {
      final m = {
        'names': [
          {'name': 'Гость'},
          {'name': 'Другой'},
        ],
      };
      expect(displayContactName(m), 'Гость');
    });

    test('никогда не возвращает сырой дамп списка', () {
      final m = {
        'names': [
          {'name': 'Я', 'type': 'CUSTOM'},
        ],
      };
      final r = displayContactName(m);
      expect(r, isNot(contains('{')));
      expect(r, isNot(contains('type')));
    });

    test('пусто/мусор → null', () {
      expect(displayContactName({}), isNull);
      expect(displayContactName({'names': <Object?>[]}), isNull);
      expect(displayContactName({'name': '   '}), isNull);
    });
  });
}
