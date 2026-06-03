import 'package:flutter_test/flutter_test.dart';
import 'package:maxim_messenger/data/max/control_event.dart';

void main() {
  group('controlEventText', () {
    test('не-CONTROL attach -> null', () {
      expect(controlEventText({'_type': 'PHOTO'}), isNull);
      expect(controlEventText({'_type': 'FILE', 'event': 'add'}), isNull);
    });

    test('add / remove / leave', () {
      expect(controlEventText({'_type': 'CONTROL', 'event': 'add'}),
          'Участник добавлен');
      expect(controlEventText({'_type': 'CONTROL', 'event': 'remove'}),
          'Участник удалён');
      expect(controlEventText({'_type': 'CONTROL', 'event': 'leave'}),
          'Участник вышел');
    });

    test('title с новым именем', () {
      expect(
        controlEventText({'_type': 'CONTROL', 'event': 'title', 'title': 'Команда'}),
        'Название изменено: Команда',
      );
    });

    test('title без имени', () {
      expect(controlEventText({'_type': 'CONTROL', 'event': 'title'}),
          'Название чата изменено');
    });

    test('неизвестное событие', () {
      expect(controlEventText({'_type': 'CONTROL', 'event': 'whatever'}),
          'Системное событие: whatever');
    });

    test('CONTROL без event', () {
      expect(controlEventText({'_type': 'CONTROL'}), 'Системное событие');
    });
  });
}
