import 'package:flutter/foundation.dart';

/// Signals that Calendar's persisted Plan records changed. Consumers reload
/// from [ScheduleRepository]; this notifier never carries a copied record.
final ValueNotifier<int> schedulePlanRevisionNotifier = ValueNotifier(0);

void notifySchedulePlanChanged() {
  schedulePlanRevisionNotifier.value++;
}
