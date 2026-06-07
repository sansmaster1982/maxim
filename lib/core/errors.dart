class MaxError implements Exception {
  final String message;
  const MaxError(this.message);
  @override
  String toString() => 'MaxError: $message';
}

class MaxLoginFailed extends MaxError {
  const MaxLoginFailed(super.message);
  @override
  String toString() => 'MaxLoginFailed: $message';
}

class MaxNotConnected extends MaxError {
  const MaxNotConnected(super.message);
  @override
  String toString() => 'MaxNotConnected: $message';
}

class MaxTimeout extends MaxError {
  const MaxTimeout(super.message);
  @override
  String toString() => 'MaxTimeout: $message';
}

/// Бизнес-отказ сервера (cmd=3). [reason] — код из payload
/// ({error, message, localizedMessage}). Повтор помогает ТОЛЬКО если причина
/// транзиентная; постоянные коды (whitelist) повторять нельзя — иначе вечный
/// долбёж сервера, а это бан-сигнал (анти-бан правило 6).
class MaxRejected extends MaxError {
  final int cmd;
  final String? reason;
  const MaxRejected(super.message, this.cmd, {this.reason});

  bool get isPermanent => const {
    'user.not.found',
    'chat.not.found',
    'recipient.not.found',
    'user.blocked',
  }.contains(reason);

  @override
  String toString() => 'MaxRejected(cmd=$cmd, reason=$reason): $message';
}
