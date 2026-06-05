import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';

import '../../core/constants.dart';

/// Сборка поля `userAgent` для SESSION_INIT (opcode 6).
///
/// Зачем: урезанный userAgent (`deviceType/locale/appVersion`) сам по себе
/// отличает клиент от официального. Реверс протокола (gist koval01,
/// openmax-server) показывает полный набор из 11 полей в строгом порядке:
/// `pushDeviceType` обязан идти ВТОРЫМ, `deviceType` — в верхнем регистре.
/// Сервер MAX не проверяет TLS/JA3, поэтому самосогласованный правдоподобный
/// userAgent безопасен и убирает дешёвый сигнал «не родной клиент».
///
/// Обогащаем только ANDROID-путь (там, где идут SMS-входы и баны). WEB и
/// прочее оставляем минимальными — этот путь (вход по веб-токену) уже
/// работает, а официальный WEB-userAgent не реверснут, ломать его смысла нет.
///
/// Порядок ключей сохраняется: литералы Map в Dart — LinkedHashMap, msgpack
/// сериализует в порядке вставки.
class DeviceProfile {
  const DeviceProfile._();

  static Future<Map<String, Object?>> userAgent(String deviceType) async {
    if (deviceType != 'ANDROID') {
      return minimal(deviceType);
    }

    // По умолчанию — согласованный пресет реального Android-устройства
    // (модель/SDK/arch/экран из одного телефона). Нужен на iOS/desktop/CLI,
    // где Android-канала нет: раньше там userAgent отдавал deviceName="Android"
    // + чужое разрешение экрана (на iPhone — iOS-овское), чего у живых
    // Android-телефонов не бывает. Это дешёвый бан-сигнал, пресет его убирает.
    var arch = _fbArch;
    var osVersion = _fbSdk;
    var deviceName = _fbName;
    var screen = _fbScreen;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.supportedAbis.isNotEmpty) {
        arch = info.supportedAbis.first;
      }
      osVersion = '${info.version.sdkInt}';
      final man = info.manufacturer.trim();
      final model = info.model.trim();
      final name = man.isEmpty ? model : '$man $model';
      if (name.trim().isNotEmpty) deviceName = name.trim();

      // Реальный экран берём только на настоящем Android — там модель и
      // разрешение из одного устройства. На пресет-пути (iOS) экран уже
      // согласован с моделью, чужое разрешение туда тащить нельзя.
      final size = ui.PlatformDispatcher.instance.implicitView?.physicalSize;
      if (size != null && size.width > 0 && size.height > 0) {
        screen = '${size.width.round()}x${size.height.round()}';
      }
    } catch (_) {
      // Нет нативного Android-канала — остаётся согласованный пресет.
    }

    // Порядок строго как у официального клиента (pushDeviceType — 2-й).
    return {
      'deviceType': 'ANDROID',
      'pushDeviceType': 'GCM',
      'appVersion': MaxProto.appVersion,
      'arch': arch,
      'buildNumber': MaxProto.appBuild,
      'osVersion': osVersion,
      'locale': MaxProto.locale,
      'deviceLocale': MaxProto.deviceLocale,
      'deviceName': deviceName,
      'screen': screen,
      'timezone': _ianaTimezone(),
    };
  }

  // Согласованный пресет: Samsung Galaxy A54 5G (SM-A546E), Android 14.
  // Недорогой и массовый в РФ телефон — userAgent сливается с толпой реальных
  // устройств, а не торчит дефолтной заглушкой "Android"/sdk34. Все 4 поля из
  // одного устройства, поэтому модель и разрешение не противоречат друг другу.
  static const _fbName = 'samsung SM-A546E';
  static const _fbSdk = '34';
  static const _fbArch = 'arm64-v8a';
  static const _fbScreen = '1080x2340';

  /// Проверенный рабочим python-клиентом минимум — для WEB и fallback.
  static Map<String, Object?> minimal(String deviceType) => {
    'deviceType': deviceType,
    'locale': MaxProto.locale,
    'appVersion': MaxProto.appVersion,
  };

  /// Best-effort IANA-таймзона по смещению. Сервер таймзону жёстко не
  /// валидирует (у реальных клиентов она разная); важна правдоподобность.
  static String _ianaTimezone() {
    final off = DateTime.now().timeZoneOffset.inHours;
    switch (off) {
      case 2:
        return 'Europe/Kaliningrad';
      case 3:
        return 'Europe/Moscow';
      case 4:
        return 'Asia/Tbilisi';
      case 5:
        return 'Asia/Yekaterinburg';
      case 6:
        return 'Asia/Omsk';
      case 7:
        return 'Asia/Krasnoyarsk';
      case 8:
        return 'Asia/Irkutsk';
      case 9:
        return 'Asia/Yakutsk';
      case 10:
        return 'Asia/Vladivostok';
      case 11:
        return 'Asia/Magadan';
      case 12:
        return 'Asia/Kamchatka';
      default:
        return 'Europe/Moscow';
    }
  }
}
