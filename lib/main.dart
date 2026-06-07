import 'dart:io' show Platform, File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _initSqflitePlatform();
  await _initDiagLog();
  await initializeDateFormatting('ru_RU', null);
  await initializeDateFormatting('ru', null);
  Intl.defaultLocale = 'ru_RU';
  runApp(const ProviderScope(child: MaximApp()));
}

/// Диагностический лог в файл Documents/maxim_diag.log — чтобы снять с iPhone
/// (idevicesyslog Flutter-логи release не показывает). Truncate на каждый старт.
Future<void> _initDiagLog() async {
  if (kIsWeb || !kDeviceDiagnostics) return;
  try {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/maxim_diag.log');
    f.writeAsStringSync('=== maxim diag ${DateTime.now().toIso8601String()} ===\n');
    diagLogFile = f;
  } catch (_) {}
}

/// На Windows/Linux/macOS — sqflite через FFI. На Android/iOS — нативный.
void _initSqflitePlatform() {
  if (kIsWeb) return;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
