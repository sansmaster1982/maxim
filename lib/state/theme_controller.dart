import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Строка из secure storage -> ThemeMode. Неизвестное/null -> system. Чистая.
ThemeMode themeModeFromString(String? s) {
  switch (s) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

/// ThemeMode -> строка для хранения. Чистая.
String themeModeToString(ThemeMode m) {
  switch (m) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

/// Выбор темы оформления с персистом в secure storage. До загрузки — system.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    Future.microtask(_load);
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final s = await ref.read(secureStorageProvider).readThemeMode();
    state = themeModeFromString(s);
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref
        .read(secureStorageProvider)
        .writeThemeMode(themeModeToString(mode));
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
