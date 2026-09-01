import 'dart:async';

import 'package:flutter/foundation.dart';

class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  /// Run action after delay, cancelling any pending previous action
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancel current pending timer
  void cancel() {
    _timer?.cancel();
  }

  /// Dispose timer when parent widget/controller is destroyed
  void dispose() {
    _timer?.cancel();
  }
}
