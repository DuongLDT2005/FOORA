import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  /// Log debug message
  static void d(String message) {
    if (!kReleaseMode) {
      debugPrint('🐛 [DEBUG]: $message');
    }
  }

  /// Log informative message
  static void i(String message) {
    if (!kReleaseMode) {
      debugPrint('ℹ️ [INFO]: $message');
    }
  }

  /// Log warning message
  static void w(String message) {
    if (!kReleaseMode) {
      debugPrint('⚠️ [WARN]: $message');
    }
  }

  /// Log error message with optional error object and stack trace
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!kReleaseMode) {
      debugPrint('🔴 [ERROR]: $message');
      if (error != null) {
        debugPrint('   Details: $error');
      }
      if (stackTrace != null) {
        debugPrint('   StackTrace:\n$stackTrace');
      }
    }
  }
}
