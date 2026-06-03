import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'state/theme_controller.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme/app_theme.dart';

class MaximApp extends ConsumerWidget {
  const MaximApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppMeta.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      home: const SplashScreen(),
    );
  }
}
