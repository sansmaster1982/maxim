import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../state/session_controller.dart';
import '../../state/theme_controller.dart';
import 'sessions_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Версия приложения'),
            subtitle: const Text('${AppMeta.name} 0.1.0'),
            leading: const Icon(Icons.info_outline),
          ),
          ListTile(
            title: const Text('Версия протокола MAX'),
            subtitle: Text('app ${MaxProto.appVersion}, '
                'proto v${MaxProto.protoVersion}'),
            leading: const Icon(Icons.cloud_outlined),
          ),
          ListTile(
            title: const Text('Тема оформления'),
            subtitle: Text(_themeLabel(ref.watch(themeModeProvider))),
            leading: const Icon(Icons.brightness_6_outlined),
            onTap: () => _pickTheme(context, ref),
          ),
          const Divider(),
          ListTile(
            title: const Text('Активные сессии'),
            subtitle: const Text('Устройства, где выполнен вход'),
            leading: const Icon(Icons.devices_outlined),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SessionsScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Выйти из аккаунта'),
            leading: const Icon(Icons.logout),
            iconColor: Theme.of(context).colorScheme.error,
            textColor: Theme.of(context).colorScheme.error,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Выйти?'),
                  content: const Text(
                    'Локальная история чатов и контактов останется, '
                    'но потребуется повторный логин.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Отмена'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Выйти'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              await ref.read(sessionProvider.notifier).logout();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode m) {
    switch (m) {
      case ThemeMode.system:
        return 'Системная';
      case ThemeMode.light:
        return 'Светлая';
      case ThemeMode.dark:
        return 'Тёмная';
    }
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final current = ref.read(themeModeProvider);
    final picked = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Тема оформления'),
        children: [
          for (final m in ThemeMode.values)
            RadioListTile<ThemeMode>(
              value: m,
              groupValue: current,
              title: Text(_themeLabel(m)),
              onChanged: (v) => Navigator.of(ctx).pop(v),
            ),
        ],
      ),
    );
    if (picked != null) {
      await ref.read(themeModeProvider.notifier).set(picked);
    }
  }
}
