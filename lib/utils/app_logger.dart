import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void warning(String message, [Object? error]) {
    _write('WARN', message, error);
  }

  static void error(String message, [Object? error]) {
    _write('ERROR', message, error);
  }

  static void _write(String level, String message, Object? error) {
    final suffix = error == null ? '' : ': $error';
    debugPrint('[$level] $message$suffix');
  }
}
