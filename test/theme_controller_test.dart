import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxim_messenger/state/theme_controller.dart';

void main() {
  group('theme mode mapping', () {
    test('fromString', () {
      expect(themeModeFromString('light'), ThemeMode.light);
      expect(themeModeFromString('dark'), ThemeMode.dark);
      expect(themeModeFromString('system'), ThemeMode.system);
      expect(themeModeFromString(null), ThemeMode.system);
      expect(themeModeFromString('мусор'), ThemeMode.system);
    });

    test('toString', () {
      expect(themeModeToString(ThemeMode.light), 'light');
      expect(themeModeToString(ThemeMode.dark), 'dark');
      expect(themeModeToString(ThemeMode.system), 'system');
    });

    test('round-trip', () {
      for (final m in ThemeMode.values) {
        expect(themeModeFromString(themeModeToString(m)), m);
      }
    });
  });
}
