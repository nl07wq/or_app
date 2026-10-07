import 'package:flutter/foundation.dart';

/// Signals that persisted Schedule or Reminder plan data changed. Consumers
/// reload from the authoritative repositories; this notifier never carries a
/// copied record or projection.
final ValueNotifier<int> schedulePlanRevisionNotifier = ValueNotifier(0);

void notifySchedulePlanChanged() {
  schedulePlanRevisionNotifier.value++;
}
