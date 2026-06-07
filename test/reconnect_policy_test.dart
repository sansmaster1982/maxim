import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxim_messenger/data/max/reconnect_policy.dart';

/// Random, который всегда даёт 0 — убираем джиттер для детерминизма.
class _ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.0;
}

void main() {
  final p = ReconnectPolicy(random: _ZeroRandom());

  group('ReconnectPolicy — анти-бан правила 1 и 3', () {
    test('authThrottle: <30с с LOGIN → ждём остаток до 30с; >=30с → 0', () {
      expect(p.authThrottle(const Duration(seconds: 5)),
          const Duration(seconds: 25));
      expect(p.authThrottle(const Duration(seconds: 30)), Duration.zero);
      expect(p.authThrottle(const Duration(seconds: 40)), Duration.zero);
    });

    test('baseBackoff: 5,10,20с экспонента, cap maxDelay (5мин)', () {
      expect(p.baseBackoff(0), const Duration(seconds: 5));
      expect(p.baseBackoff(1), const Duration(seconds: 10));
      expect(p.baseBackoff(2), const Duration(seconds: 20));
      expect(p.baseBackoff(20), const Duration(minutes: 5));
    });

    test('breakerTripped: срабатывает на >=6 попыток в окне', () {
      expect(p.breakerTripped(5), isFalse);
      expect(p.breakerTripped(6), isTrue);
      expect(p.breakerTripped(7), isTrue);
    });

    test('nextDelay: дроп сразу после LOGIN троттлится до 30с (правило 1)', () {
      // логинились 1с назад, первая попытка → ждём ~29с (throttle), не 5с backoff
      final d = p.nextDelay(
        attempt: 0,
        sinceLastLogin: const Duration(seconds: 1),
        attemptsInWindow: 0,
      );
      expect(d, const Duration(seconds: 29));
    });

    test('nextDelay: флаппинг включает cooldown 8мин (правило 3)', () {
      final d = p.nextDelay(
        attempt: 0,
        sinceLastLogin: const Duration(hours: 1), // throttle=0
        attemptsInWindow: 6, // tripped
      );
      expect(d, const Duration(minutes: 8));
    });

    test('nextDelay: стабильная сессия (логинились давно) → reconnect сразу', () {
      final d = p.nextDelay(
        attempt: 0,
        sinceLastLogin: const Duration(hours: 1),
        attemptsInWindow: 0,
      );
      expect(d, const Duration(seconds: 5)); // только backoff, без троттла
    });
  });
}
