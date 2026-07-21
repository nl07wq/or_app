import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/daily_log_confirmation.dart';
import 'package:or_app/core/repositories/daily_log_confirmation_repository.dart';
import 'package:or_app/core/services/daily_log_mutation_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final confirmedDate = DateTime(2026, 7, 21);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DailyLogConfirmationRepository.save(
      DailyLogConfirmation(
        date: confirmedDate,
        confirmedAt: DateTime(2026, 7, 21, 21),
        morning: null,
        food: null,
        activity: null,
        training: null,
      ),
    );
  });

  for (final label in [
    'Morning save', 'Morning delete', 'Food save', 'Food delete',
    'Water save', 'Water delete', 'Activity save', 'Activity delete',
    'Training save', 'Training delete',
  ]) {
    test('$label is blocked for a confirmed date', () async {
      await expectLater(
        DailyLogMutationGuard.assertDateMutable(confirmedDate),
        throwsA(isA<ConfirmedDailyLogException>()),
      );
    });
  }

  test('a stale flow rechecks confirmation at mutation time', () async {
    final target = DateTime(2026, 7, 22);
    expect(await DailyLogMutationGuard.isDateConfirmed(target), isFalse);
    await DailyLogConfirmationRepository.save(DailyLogConfirmation(date: target, confirmedAt: DateTime.now(), morning: null, food: null, activity: null, training: null));
    await expectLater(DailyLogMutationGuard.assertDateMutable(target), throwsA(isA<ConfirmedDailyLogException>()));
  });

  test('another unconfirmed date remains mutable', () async {
    await DailyLogMutationGuard.assertDateMutable(DateTime(2026, 7, 22));
  });

  test('exception has the required Japanese message', () {
    expect(const ConfirmedDailyLogException().toString(), ConfirmedDailyLogException.message);
  });
}
