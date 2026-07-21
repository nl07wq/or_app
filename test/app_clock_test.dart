import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/app_clock.dart';

void main() {
  setUp(AppClock.resetForTesting);
  tearDown(AppClock.resetForTesting);

  test('returns the system clock when no Debug override is set', () {
    final systemNow = DateTime(2026, 7, 22, 14, 30);
    AppClock.setSystemNowForTesting(() => systemNow);

    expect(AppClock.now(), systemNow);
  });

  test('returns the Debug override when it is enabled', () {
    AppClock.setSystemNowForTesting(() => DateTime(2026, 7, 22, 14, 30));
    AppClock.setDebugDate(DateTime(2026, 7, 23, 18, 45));

    expect(AppClock.now(), DateTime(2026, 7, 23));
    expect(AppClock.hasDebugDateOverride, isTrue);
  });

  test('returns to the system clock after clearing the Debug override', () {
    final systemNow = DateTime(2026, 7, 22, 14, 30);
    AppClock.setSystemNowForTesting(() => systemNow);
    AppClock.setDebugDate(DateTime(2026, 7, 23));

    AppClock.clearDebugDateOverride();

    expect(AppClock.now(), systemNow);
    expect(AppClock.hasDebugDateOverride, isFalse);
  });

  test('today removes the time portion of the current clock value', () {
    AppClock.setSystemNowForTesting(() => DateTime(2026, 7, 22, 14, 30));

    expect(AppClock.today(), DateTime(2026, 7, 22));
  });
}
