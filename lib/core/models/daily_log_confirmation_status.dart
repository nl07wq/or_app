import 'daily_log_confirmation.dart';

class DailyLogConfirmationStatus {
  final bool isConfirmed;
  final DateTime? confirmedAt;
  final DateTime date;

  DailyLogConfirmationStatus.unconfirmed(DateTime date)
      : isConfirmed = false,
        confirmedAt = null,
        date = DateTime(date.year, date.month, date.day);

  DailyLogConfirmationStatus.confirmed(DailyLogConfirmation confirmation)
      : isConfirmed = true,
        confirmedAt = confirmation.confirmedAt,
        date = confirmation.date;
}
