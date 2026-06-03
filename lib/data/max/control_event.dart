/// Человекочитаемый текст системного события чата из attach `_type=CONTROL`.
///
/// Поля события — из docs/MEDIA_OPCODES.md (defpackage/zs4.java): `event` ∈
/// {new, add, remove, leave, title, icon, pin, joinByLink, call, ...}, плюс
/// опциональные title/userId/userIds. Возвращает null, если attach не CONTROL.
/// Чистая функция — под юнит-тест.
String? controlEventText(Map<String, dynamic> attach) {
  final type = (attach['_type'] ?? attach['type'])?.toString().toUpperCase();
  if (type != 'CONTROL') return null;

  final event = (attach['event'] ?? '').toString().toLowerCase();
  switch (event) {
    case 'new':
      return 'Чат создан';
    case 'add':
      return 'Участник добавлен';
    case 'remove':
      return 'Участник удалён';
    case 'leave':
      return 'Участник вышел';
    case 'title':
      final t = attach['title']?.toString();
      return (t != null && t.isNotEmpty)
          ? 'Название изменено: $t'
          : 'Название чата изменено';
    case 'icon':
      return 'Аватар чата изменён';
    case 'pin':
      return 'Закреплено сообщение';
    case 'unpin':
      return 'Сообщение откреплено';
    case 'joinbylink':
      return 'Присоединился по ссылке';
    case 'call':
      return 'Звонок';
    default:
      return event.isNotEmpty ? 'Системное событие: $event' : 'Системное событие';
  }
}
