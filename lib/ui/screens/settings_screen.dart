import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/max/contact_name.dart';
import '../../state/providers.dart';
import '../../state/session_controller.dart';
import 'devices_screen.dart';

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
          const Divider(),
          ListTile(
            title: const Text('Изменить имя'),
            subtitle: const Text('Имя, которое видят собеседники'),
            leading: const Icon(Icons.badge_outlined),
            onTap: () => _editName(context, ref),
          ),
          const Divider(),
          ListTile(
            title: const Text('Устройства и сессии'),
            subtitle: const Text('Активные входы · завершить чужие'),
            leading: const Icon(Icons.devices_outlined),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DevicesScreen()),
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

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final client = ref.read(maxClientProvider);
    final ctrl = TextEditingController();
    // best-effort: подставить текущее имя профиля
    try {
      final prof = await client.currentProfile();
      final p = prof['profile'];
      final contact = (p is Map) ? p['contact'] : prof['contact'];
      if (contact is Map) {
        final m = contact.map((k, v) => MapEntry(k.toString(), v));
        final name = displayContactName(m);
        if (name != null) ctrl.text = name;
      }
    } catch (_) {}
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Изменить имя'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Имя',
            hintText: 'Как тебя видят другие',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    try {
      await client.updateProfileName(newName);
      messenger.showSnackBar(
        SnackBar(content: Text('Имя изменено: «$newName»')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось сменить имя: $e')),
      );
    }
  }
}
