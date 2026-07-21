import 'package:flutter/foundation.dart';

import '../models/daily_log_confirmation_status.dart';
import '../repositories/daily_log_confirmation_repository.dart';

final ValueNotifier<DailyLogConfirmationStatus> dailyLogConfirmationNotifier =
    ValueNotifier(DailyLogConfirmationStatus.unconfirmed(DateTime.now()));

Future<void> refreshDailyLogConfirmationStatus() async {
  final today = DateTime.now();
  final confirmation = await DailyLogConfirmationRepository.findByDate(today);
  dailyLogConfirmationNotifier.value = confirmation == null
      ? DailyLogConfirmationStatus.unconfirmed(today)
      : DailyLogConfirmationStatus.confirmed(confirmation);
}
