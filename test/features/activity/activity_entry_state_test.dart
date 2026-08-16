import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/core/widgets/operation_button.dart';
import 'package:or_app/core/widgets/operation_card.dart';
import 'package:or_app/features/activity/activity_entry_page.dart';
import 'package:or_app/features/activity/activity_page.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../operation_date/operation_date_test_fixture.dart';

void main() {
  late FakeIndexedDbDatabase database;
  final currentDate = DateTime(2026, 8, 16);
  final historicalDate = DateTime(2026, 8, 15);

  setUp(() {
    database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-08-16');
    final controller = AppInitializationController()..markReady();
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets(
    'ACTIVITY ENTRY follows the current record through edit delete and recreate',
    (tester) async {
      await _pumpActivity(tester);

      expect(find.text('MANUAL ENTRY'), findsNothing);
      expect(find.text('ACTIVITY ENTRY'), findsNWidgets(2));
      expect(_entryButton(tester).onPressed, isNotNull);
      expect(find.textContaining('本日のACTIVITYは登録済みです。'), findsNothing);

      await AppRepositoryRegistry.container.activity.save(
        _activity(currentDate, steps: 5000),
      );
      await AppRepositoryRegistry.container.activity.save(
        _activity(historicalDate, steps: 4000),
      );
      await _pumpActivity(tester, key: 'activity-with-records');

      expect(_entryButton(tester).onPressed, isNull);
      expect(
        find.text('本日のACTIVITYは登録済みです。\n編集する場合はRECORDから行ってください。'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.descendant(
                of: find.byKey(const ValueKey('activity-entry-button')),
                matching: find.byType(ElevatedButton),
              ),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('RECORD').last);
      await tester.pumpAndSettle();
      await _deleteActivity(tester, '2026-08-15');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_entryButton(tester).onPressed, isNull);

      await tester.tap(find.text('RECORD').last);
      await tester.pumpAndSettle();
      await _editActivity(tester, '2026-08-16');
      expect(find.byType(ActivityEntryPage), findsOneWidget);
      expect(find.text('SAVE ACTIVITY'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _deleteActivity(tester, '2026-08-16');
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(_entryButton(tester).onPressed, isNotNull);
      expect(find.textContaining('本日のACTIVITYは登録済みです。'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('activity-entry-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '6000');
      await tester.enterText(find.byType(TextField).at(1), '0');
      final noDigestive = find.widgetWithText(ChoiceChip, 'なし');
      await tester.ensureVisible(noDigestive);
      await tester.tap(noDigestive);
      await tester.ensureVisible(find.text('SAVE ACTIVITY'));
      await tester.tap(find.text('SAVE ACTIVITY'));
      await tester.pumpAndSettle();

      expect(find.byType(ActivityPage), findsOneWidget);
      expect(_entryButton(tester).onPressed, isNull);
      expect(
        (await AppRepositoryRegistry.container.activity.findByDate(
          currentDate,
        ))?.measuredSteps,
        6000,
      );

      await _pumpActivity(tester, key: 'activity-reloaded');
      expect(_entryButton(tester).onPressed, isNull);
    },
  );

  testWidgets('ACTIVITY entry state has no overflow at supported widths', (
    tester,
  ) async {
    for (final width in const [320.0, 390.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await _pumpActivity(tester, key: 'activity-width-$width');
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpActivity(
  WidgetTester tester, {
  String key = 'activity-empty',
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    MaterialApp(
      initialRoute: AppRoutes.activity,
      routes: {AppRoutes.activity: (_) => ActivityPage(key: ValueKey(key))},
    ),
  );
  await tester.pumpAndSettle();
}

OperationButton _entryButton(WidgetTester tester) =>
    tester.widget(find.byKey(const ValueKey('activity-entry-button')));

Future<void> _deleteActivity(WidgetTester tester, String localDate) async {
  final card = find.ancestor(
    of: find.text(localDate),
    matching: find.byType(OperationCard),
  );
  await tester.tap(
    find.descendant(of: card, matching: find.byIcon(Icons.delete_outline)),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('削除'));
  await tester.pumpAndSettle();
}

Future<void> _editActivity(WidgetTester tester, String localDate) async {
  final card = find.ancestor(
    of: find.text(localDate),
    matching: find.byType(OperationCard),
  );
  await tester.tap(
    find.descendant(of: card, matching: find.byIcon(Icons.edit_outlined)),
  );
  await tester.pumpAndSettle();
}

ActivityData _activity(DateTime date, {required int steps}) => ActivityData(
  date: date,
  measuredSteps: steps,
  carryOver: 0,
  stepsEntered: true,
  carryOverEntered: true,
);
