import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/max/models/session.dart';
import '../../state/providers.dart';

/// Активные сессии аккаунта (opcode 96). Можно завершить чужую сессию (97).
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  late Future<List<MaxSession>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<MaxSession>> _load() async {
    final client = ref.read(maxClientProvider);
    final res = await client.sessionsInfo();
    return parseSessions(res);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _terminate(MaxSession s) async {
    final client = ref.read(maxClientProvider);
    try {
      await client.sessionsClose([s.id]);
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось завершить сессию: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Активные сессии')),
      body: FutureBuilder<List<MaxSession>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Не удалось загрузить сессии:\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final sessions = snap.data ?? const <MaxSession>[];
          if (sessions.isEmpty) {
            return const Center(child: Text('Сессии не найдены'));
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) {
                final s = sessions[i];
                final parts = <String>[
                  if (s.device != null) s.device!,
                  if (s.lastSeenMs != null)
                    DateFormat('d MMM, HH:mm', 'ru_RU').format(
                      DateTime.fromMillisecondsSinceEpoch(s.lastSeenMs!),
                    ),
                  if (s.isCurrent) 'текущая',
                ];
                return ListTile(
                  leading: const Icon(Icons.devices_outlined),
                  title: Text(s.name ?? s.device ?? 'Сессия ${s.id}'),
                  subtitle: parts.isEmpty ? null : Text(parts.join(' • ')),
                  trailing: s.isCurrent
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.logout),
                          tooltip: 'Завершить',
                          onPressed: () => _terminate(s),
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
