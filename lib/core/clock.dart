import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time; overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The current time, refreshed at the start of every minute, for UI that
/// shows clock times. The timer stops when nothing is listening.
class MinuteTick extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final clock = ref.watch(clockProvider);
    ref.onDispose(() => _timer?.cancel());
    _scheduleNext(clock);
    return clock();
  }

  void _scheduleNext(DateTime Function() clock) {
    final now = clock();
    _timer?.cancel();
    _timer = Timer(
      Duration(seconds: 60 - now.second, milliseconds: -now.millisecond),
      () {
        state = clock();
        _scheduleNext(clock);
      },
    );
  }
}

final minuteTickProvider = NotifierProvider.autoDispose<MinuteTick, DateTime>(
  MinuteTick.new,
);
