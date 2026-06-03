import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxim_messenger/data/max/raw_parsers.dart';

Uint8List _buf(List<List<int>> parts) {
  final b = BytesBuilder();
  for (final p in parts) {
    b.add(p);
  }
  return b.toBytes();
}

void main() {
  group('RawParsers.extractChatIds', () {
    test('тащит chatId (int32) и id с маркером типа, пропускает «голый» id', () {
      final data = _buf([
        // \xA6chatId \xD2 <int32 = 1234>
        [0xA6], 'chatId'.codeUnits, [0xD2, 0x00, 0x00, 0x04, 0xD2],
        // \xA2id \xD3 <int64 = 5678> ... "CHAT" в пределах окна
        [0xA2], 'id'.codeUnits,
        [0xD3, 0, 0, 0, 0, 0, 0, 0x16, 0x2E], [0x00, 0x00], 'CHAT'.codeUnits,
        // \xA2id \xD2 <int32 = 999> без маркера типа рядом -> исключается
        [0xA2], 'id'.codeUnits, [0xD2, 0x00, 0x00, 0x03, 0xE7],
        List<int>.filled(160, 0),
      ]);
      expect(RawParsers.extractChatIds(data), [1234, 5678]);
    });

    test('дедуп повторяющихся id', () {
      final data = _buf([
        [0xA6], 'chatId'.codeUnits, [0xD2, 0x00, 0x00, 0x00, 0x07],
        [0xA6], 'chatId'.codeUnits, [0xD2, 0x00, 0x00, 0x00, 0x07],
      ]);
      expect(RawParsers.extractChatIds(data), [7]);
    });

    test('пустые данные -> пустой список', () {
      expect(RawParsers.extractChatIds(Uint8List(0)), isEmpty);
    });
  });
}
