import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/operation_status.dart';
import 'package:or_app/features/dashboard/widgets/operation_ambient_animation.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/themes/base_camp/base_camp_dashboard_page.dart';

import '../../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../../operation_date/operation_date_test_fixture.dart';

void main() {
  setUp(() {
    final database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-11-01');
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets('BASE CAMP owns a compact terminal and retains a 16:9 map', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('base-camp-tactical-terminal')),
      findsOneWidget,
    );
    expect(find.text('ASSET PENDING'), findsOneWidget);
    expect(find.text('OPERATION PROGRESS'), findsOneWidget);
    expect(find.byType(OperationAmbientAnimation), findsOneWidget);
    final waveform = tester.widget<OperationAmbientAnimation>(
      find.byType(OperationAmbientAnimation),
    );
    expect(waveform.showStatusLabel, isFalse);
    expect(
      find.byKey(const ValueKey('base-camp-industrial-lcd')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('base-camp-map')), findsOneWidget);
    final mapSize = tester.getSize(find.byKey(const ValueKey('base-camp-map')));
    expect(mapSize.width / mapSize.height, closeTo(16 / 9, .02));
    final viewport = tester.getSize(
      find.byKey(const ValueKey('base-camp-home-map-viewport')),
    );
    expect(viewport.height, greaterThan(mapSize.height));
    expect(tester.takeException(), isNull);
  });

  testWidgets('terminal pages swipe and open an expanded detail sheet', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.drag(
      find.byKey(const ValueKey('base-camp-terminal-pages')),
      const Offset(-320, 0),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final page = find.byKey(const ValueKey('base-camp-terminal-page-morning'));
    expect(page, findsOneWidget);
    await tester.ensureVisible(page);
    await tester.pump();
    await tester.tap(page);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('OPEN STATUS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LCD previews use an equal three-column grid', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: BaseCampDashboardPage()));
    await tester.pump(const Duration(milliseconds: 300));

    final grid = tester.widget<GridView>(
      find.descendant(
        of: find.byKey(const ValueKey('base-camp-progress-grid')),
        matching: find.byType(GridView),
      ),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
    expect(delegate.crossAxisSpacing, 6);
    expect(delegate.mainAxisSpacing, 6);
  });

  testWidgets('ambient waveform preserves the STANDARD label by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OperationAmbientAnimation(status: OperationStatus.green),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('operation-ambient-status-label')),
      findsOneWidget,
    );
  });
}
