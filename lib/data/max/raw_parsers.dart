import 'dart:convert';
import 'dart:typed_data';

/// Минимальные парсеры значений msgpack по сырому байту, чтобы
/// добывать поля по имени-ключу когда полная декодировка не сработала.
/// Копия helpers из telega-to-max/max_client.py.
class RawParsers {
  static int? readIntAfterKey(Uint8List data, Uint8List key) {
    final pos = _indexOf(data, key);
    if (pos == -1) return null;
    var p = pos + key.length;
    if (p >= data.length) return null;
    final typ = data[p];
    p += 1;
    if (typ == 0xD2 && p + 4 <= data.length) {
      return ByteData.sublistView(data, p, p + 4).getInt32(0, Endian.big);
    }
    if (typ == 0xD3 && p + 8 <= data.length) {
      return ByteData.sublistView(data, p, p + 8).getInt64(0, Endian.big);
    }
    if (typ <= 0x7F) return typ;
    if (typ >= 0xE0) return typ - 256;
    return null;
  }

  static String? readStrAfterKey(Uint8List data, Uint8List key) {
    final pos = _indexOf(data, key);
    if (pos == -1) return null;
    var p = pos + key.length;
    if (p >= data.length) return null;
    final typ = data[p];
    p += 1;
    int n;
    if (typ >= 0xA0 && typ <= 0xBF) {
      n = typ & 0x1F;
    } else if (typ == 0xD9 && p < data.length) {
      n = data[p];
      p += 1;
    } else if (typ == 0xDA && p + 2 <= data.length) {
      n = ByteData.sublistView(data, p, p + 2).getUint16(0, Endian.big);
      p += 2;
    } else if (typ == 0xDB && p + 4 <= data.length) {
      n = ByteData.sublistView(data, p, p + 4).getUint32(0, Endian.big);
      p += 4;
    } else {
      return null;
    }
    if (p + n > data.length) return null;
    return utf8.decode(data.sublist(p, p + n), allowMalformed: true).trim();
  }

  static String? findLongToken(Uint8List data) {
    const valid =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-+.~=';
    final validSet = <int>{for (final c in valid.codeUnits) c};
    String? best;
    final cur = <int>[];
    void flush() {
      if (cur.length > 100) {
        final t = String.fromCharCodes(cur);
        if (best == null || t.length > best!.length) best = t;
      }
      cur.clear();
    }

    for (final b in data) {
      if (validSet.contains(b)) {
        cur.add(b);
      } else {
        flush();
      }
    }
    flush();
    return best;
  }

  static String? findUuid(Uint8List data) {
    // UUID состоит только из ASCII символов, поэтому fromCharCodes тут безопасен.
    final text = String.fromCharCodes(data);
    final re = RegExp(
      r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
    );
    final m = re.firstMatch(text);
    return m?.group(0);
  }

  /// Достаёт id чатов из сырого (распакованного) тела LOGIN, когда compact-
  /// msgpack чатов не декодируется целиком. Порт `extract_chat_ids_from_login_raw`
  /// из maxclient: ключ "id" (\xA2id) с числом, рядом с которым в пределах ~120
  /// байт стоит маркер типа DIALOG/CHAT/CHANNEL; плюс ключ "chatId" (\xA6chatId).
  static List<int> extractChatIds(Uint8List data) {
    final result = <int>[];
    final seen = <int>{};
    void add(int? v) {
      if (v != null && v != 0 && seen.add(v)) result.add(v);
    }

    bool matchAt(int i, List<int> pat) {
      if (i + pat.length > data.length) return false;
      for (var j = 0; j < pat.length; j++) {
        if (data[i + j] != pat[j]) return false;
      }
      return true;
    }

    int? readNum(int p) {
      if (p >= data.length) return null;
      final typ = data[p];
      if (typ == 0xD2 && p + 5 <= data.length) {
        return ByteData.sublistView(data, p + 1, p + 5).getInt32(0, Endian.big);
      }
      if (typ == 0xD3 && p + 9 <= data.length) {
        return ByteData.sublistView(data, p + 1, p + 9).getInt64(0, Endian.big);
      }
      return null;
    }

    const idKey = [0xA2, 0x69, 0x64]; // \xA2 "id"
    const chatIdKey = [0xA6, 0x63, 0x68, 0x61, 0x74, 0x49, 0x64]; // \xA6 "chatId"
    const dialog = [0x44, 0x49, 0x41, 0x4C, 0x4F, 0x47]; // DIALOG
    const chat = [0x43, 0x48, 0x41, 0x54]; // CHAT
    const channel = [0x43, 0x48, 0x41, 0x4E, 0x4E, 0x45, 0x4C]; // CHANNEL

    bool typeMarkerWithin(int from, int window) {
      final end = (from + window) < data.length ? (from + window) : data.length;
      for (var i = from; i < end; i++) {
        if (matchAt(i, dialog) || matchAt(i, chat) || matchAt(i, channel)) {
          return true;
        }
      }
      return false;
    }

    for (var i = 0; i < data.length; i++) {
      if (matchAt(i, idKey)) {
        final p = i + idKey.length;
        final typ = p < data.length ? data[p] : 0;
        if (typ == 0xD2 || typ == 0xD3) {
          final value = readNum(p);
          if (value != null) {
            final valueEnd = p + 1 + (typ == 0xD2 ? 4 : 8);
            if (typeMarkerWithin(valueEnd, 120)) add(value);
          }
        }
      }
      if (matchAt(i, chatIdKey)) {
        final p = i + chatIdKey.length;
        final typ = p < data.length ? data[p] : 0;
        if (typ == 0xD2 || typ == 0xD3) add(readNum(p));
      }
    }
    return result;
  }

  static int indexOf(Uint8List haystack, Uint8List needle) => _indexOf(
    haystack,
    needle,
  );

  static int _indexOf(Uint8List haystack, Uint8List needle) {
    if (needle.isEmpty || needle.length > haystack.length) return -1;
    outer:
    for (var i = 0; i <= haystack.length - needle.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return -1;
  }
}
