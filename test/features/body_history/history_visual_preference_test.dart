import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/body_history/services/history_visual_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  HistoryVisualPreference preference() =>
      HistoryVisualPreference(preferencesLoader: () async => preferences);

  test('defaults to archive display and chrono archive', () async {
    expect(await preference().load(), const HistoryVisualSelection.defaults());
  });

  test('persists title and ambient independently', () async {
    await preference().save(
      const HistoryVisualSelection(
        title: HistoryTitleVariant.memoryModule,
        ambient: HistoryAmbientVariant.dataVault,
      ),
    );

    expect(
      await preference().load(),
      const HistoryVisualSelection(
        title: HistoryTitleVariant.memoryModule,
        ambient: HistoryAmbientVariant.dataVault,
      ),
    );
  });
}
