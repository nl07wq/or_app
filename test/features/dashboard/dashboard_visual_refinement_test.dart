import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/dashboard/dashboard_page.dart';
import 'package:or_app/features/dashboard/widgets/dashboard_ambient_wildlife_stage.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/system/pages/ambient_wildlife_v2.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../operation_date/operation_date_test_fixture.dart';

void main() {
  testWidgets(
    'wildlife keeps its production artwork above the frosted surface at supported widths',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final width in [320.0, 390.0, 900.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: width,
                child: DashboardAmbientWildlifeStage(
                  nextInt: (_) => 0,
                  minimumInterval: const Duration(days: 1),
                  maximumInterval: const Duration(days: 1),
                ),
              ),
            ),
          ),
        );

        expect(
          find.byKey(
            const ValueKey('dashboard-ambient-wildlife-frosted-surface'),
          ),
          findsOneWidget,
        );
        final production = tester.widget<AmbientWildlifeV2ProductionStage>(
          find.byType(AmbientWildlifeV2ProductionStage),
        );
        expect(production.paintEnvironment, isFalse);
        expect(
          tester
              .getSize(
                find.byKey(const ValueKey('dashboard-ambient-wildlife-stage')),
              )
              .height,
          DashboardAmbientWildlifeStage.height,
        );
      }
    },
  );

  testWidgets('Quick Access stays compact, centered, and common-width', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(AppRepositoryRegistry.resetForTesting);

    const labels = ['STATUS', 'FOOD', 'TRAINING', 'ACTIVITY', 'COMMAND CENTER'];
    for (final width in [320.0, 390.0, 900.0]) {
      final database = FakeIndexedDbDatabase();
      seedOperationState(database, '2026-07-28');
      AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final buttons = [
        for (final label in labels)
          find.byKey(ValueKey('dashboard-quick-access-button-$label')),
      ];
      final firstRect = tester.getRect(buttons.first);
      for (final button in buttons) {
        final rect = tester.getRect(button);
        expect(rect.width, 224);
        expect(rect.left, firstRect.left);
        expect(rect.right, firstRect.right);
        expect(rect.center.dx, closeTo(width / 2, .1));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Dashboard top band gains glass only while content is pinned', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(AppRepositoryRegistry.resetForTesting);
    final database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-07-28');
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
    await tester.pump(const Duration(milliseconds: 500));

    const glass = ValueKey('dashboard-pinned-top-band-glass');
    expect(find.byKey(glass), findsNothing);
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('dashboard-scroll-view')),
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pump();
    expect(find.byKey(glass), findsOneWidget);

    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
    expect(find.byKey(glass), findsNothing);
  });
}
