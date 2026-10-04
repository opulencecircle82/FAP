import 'dart:async';

import 'package:flutter/foundation.dart';

/// Shared 1 Hz flash phase so every flashing FAP indication blinks in sync.
class Blink extends ValueNotifier<bool> {
  Blink() : super(true) {
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => value = !value,
    );
  }

  late final Timer _timer;

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
