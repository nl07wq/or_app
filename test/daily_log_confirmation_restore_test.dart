import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/daily_log_confirmation_state.dart';
import 'package:or_app/core/services/daily_state_restore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => DailyStateRestoreService.resetForTesting());

  test('startup restore publishes unconfirmed status when no confirmation exists', () async {
    SharedPreferences.setMockInitialValues({});
    await DailyStateRestoreService.restore();
    expect(dailyLogConfirmationNotifier.value.isConfirmed, isFalse);
  });

  test('malformed confirmation persistence restores a safe unconfirmed state', () async {
    SharedPreferences.setMockInitialValues({
      'daily_log_confirmations': ['not-json'],
    });
    await DailyStateRestoreService.restore();
    expect(dailyLogConfirmationNotifier.value.isConfirmed, isFalse);
  });
}
