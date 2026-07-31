import 'package:flutter/foundation.dart';

import '../models/daily_log_confirmation_status.dart';
import '../repositories/daily_log_confirmation_repository.dart';
import '../../features/operation_date/services/operation_date_service.dart';

final ValueNotifier<DailyLogConfirmationStatus> dailyLogConfirmationNotifier =
    ValueNotifier(DailyLogConfirmationStatus.unconfirmed(DateTime.now()));

Future<void> refreshDailyLogConfirmationStatus({String? localDate}) async {
  final targetLocalDate =
      localDate ?? (await const OperationDateService().current()).value;
  final targetDate = DateTime.parse(targetLocalDate);
  final confirmation = await DailyLogConfirmationRepository.findByDate(
    targetDate,
  );
  dailyLogConfirmationNotifier.value = confirmation == null
      ? DailyLogConfirmationStatus.unconfirmed(targetDate)
      : DailyLogConfirmationStatus.confirmed(confirmation);
}
