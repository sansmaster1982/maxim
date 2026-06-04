import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:maxim_messenger/data/local/database.dart';
import 'package:maxim_messenger/data/max/models/message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  setUp(() async {
    // singleInstance:false — иначе ffi переиспользует один :memory: между
    // тестами и схема создаётся повторно («table already exists»).
    final raw = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await AppDatabase.createSchemaForTest(raw);
    db = AppDatabase.forDb(raw);
  });
  tearDown(() async {
    await db.raw.close();
  });

  MaxMessage msg(int chatId, String text, int t) => MaxMessage(
        chatId: chatId,
        text: text,
        timeMs: t,
        direction: MessageDirection.incoming,
      );

  test('searchMessages: подстрока, регистронезависимо для кириллицы', () async {
    await db.insertMessage(msg(1, 'Привет, как дела', 100));
    await db.insertMessage(msg(2, 'Купи молоко', 200));
    await db.insertMessage(msg(1, 'ПРИВЕТ ещё раз', 300));

    final res = await db.searchMessages('привет');
    expect(res.length, 2);
    // порядок по времени DESC -> свежее первым
    expect(res.first.text, 'ПРИВЕТ ещё раз');

    expect((await db.searchMessages('молоко')).single.chatId, 2);
    expect(await db.searchMessages('нет такого'), isEmpty);
    expect(await db.searchMessages('   '), isEmpty);
  });

  test('searchMessages: лимит результатов', () async {
    for (var i = 0; i < 10; i++) {
      await db.insertMessage(msg(1, 'тест $i', i));
    }
    final res = await db.searchMessages('тест', limit: 3);
    expect(res.length, 3);
  });

  test('setMessageReactions: counts + your_reaction, roundtrip через fromDbRow',
      () async {
    await db.insertMessage(const MaxMessage(
      id: 500,
      chatId: 1,
      text: 'hi',
      timeMs: 1,
      direction: MessageDirection.incoming,
    ));
    await db.setMessageReactions(500,
        counts: {'👍': 3, '❤️': 1}, yourReaction: '👍');
    final m = (await db.messages(1)).firstWhere((x) => x.id == 500);
    expect(m.reactions, {'👍': 3, '❤️': 1});
    expect(m.yourReaction, '👍');

    // снять свою реакцию (пустая строка -> null), счётчики не трогаем
    await db.setMessageReactions(500, yourReaction: '');
    final m2 = (await db.messages(1)).firstWhere((x) => x.id == 500);
    expect(m2.yourReaction, isNull);
    expect(m2.reactions, {'👍': 3, '❤️': 1});
  });
}
