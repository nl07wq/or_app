import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/theme/app_theme.dart';
import 'package:or_app/features/body_history/pages/data_center_history_page.dart';
import 'package:or_app/features/body_history/services/history_visual_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpHistory(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    bool animateAmbient = false,
  }) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: StandardTheme.theme,
        home: DataCenterHistoryPage(animateAmbient: animateAmbient),
      ),
    );
    await tester.pump();
  }

  testWidgets('supports all independent title and ambient combinations', (
    tester,
  ) async {
    await pumpHistory(tester);
    for (final title in HistoryTitleVariant.values) {
      for (final ambient in HistoryAmbientVariant.values) {
        await tester.tap(
          find.text(switch (title) {
            HistoryTitleVariant.archiveDisplay => 'A DISPLAY',
            HistoryTitleVariant.archivePlate => 'B PLATE',
            HistoryTitleVariant.memoryModule => 'C MODULE',
          }),
        );
        await tester.tap(
          find.text(switch (ambient) {
            HistoryAmbientVariant.chronoArchive => 'A CHRONO',
            HistoryAmbientVariant.dataVault => 'B VAULT',
            HistoryAmbientVariant.memoryStream => 'C STREAM',
          }),
        );
        await tester.pump();
        expect(
          find.byKey(ValueKey('history-title-${title.name}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('history-ambient-${ambient.name}')),
          findsOneWidget,
        );
      }
    }
  });

  testWidgets('retains the fixed title and ambient while history scrolls', (
    tester,
  ) async {
    await pumpHistory(tester);
    final titleBefore = tester.getTopLeft(
      find.byKey(const ValueKey('history-title-archiveDisplay')),
    );
    final ambientBefore = tester.getTopLeft(
      find.byKey(const ValueKey('history-ambient-chronoArchive')),
    );
    final cardBefore = tester.getTopLeft(find.text('BODY HISTORY'));

    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pump();

    expect(
      tester.getTopLeft(
        find.byKey(const ValueKey('history-title-archiveDisplay')),
      ),
      titleBefore,
    );
    expect(
      tester.getTopLeft(
        find.byKey(const ValueKey('history-ambient-chronoArchive')),
      ),
      ambientBefore,
    );
    expect(
      tester.getTopLeft(find.text('BODY HISTORY')).dy,
      lessThan(cardBefore.dy),
    );
  });

  for (final size in const [
    Size(320, 844),
    Size(375, 844),
    Size(390, 844),
    Size(430, 844),
  ]) {
    testWidgets('renders HISTORY visual controls without overflow at $size', (
      tester,
    ) async {
      await pumpHistory(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('history-visual-selector')),
        findsOneWidget,
      );
    });
  }

  testWidgets('renders the default visual golden', (tester) async {
    await pumpHistory(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/data_center_history_visual_default.png'),
    );
  });

  testWidgets('renders all HISTORY title and ambient golden combinations', (
    tester,
  ) async {
    await pumpHistory(tester);
    for (final title in HistoryTitleVariant.values) {
      for (final ambient in HistoryAmbientVariant.values) {
        await tester.tap(
          find.text(switch (title) {
            HistoryTitleVariant.archiveDisplay => 'A DISPLAY',
            HistoryTitleVariant.archivePlate => 'B PLATE',
            HistoryTitleVariant.memoryModule => 'C MODULE',
          }),
        );
        await tester.tap(
          find.text(switch (ambient) {
            HistoryAmbientVariant.chronoArchive => 'A CHRONO',
            HistoryAmbientVariant.dataVault => 'B VAULT',
            HistoryAmbientVariant.memoryStream => 'C STREAM',
          }),
        );
        await tester.pump();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/data_center_history_${title.name}_${ambient.name}.png',
          ),
        );
      }
    }
  });

  testWidgets('renders distinct title comparison goldens', (tester) async {
    await pumpHistory(tester);
    for (final title in HistoryTitleVariant.values) {
      await tester.tap(
        find.text(switch (title) {
          HistoryTitleVariant.archiveDisplay => 'A DISPLAY',
          HistoryTitleVariant.archivePlate => 'B PLATE',
          HistoryTitleVariant.memoryModule => 'C MODULE',
        }),
      );
      await tester.pump();
      await expectLater(
        find.byKey(ValueKey('history-title-${title.name}')),
        matchesGoldenFile('goldens/history_title_${title.name}.png'),
      );
    }
  });

  testWidgets('keeps each animated ambient continuous at loop boundary', (
    tester,
  ) async {
    await pumpHistory(tester, animateAmbient: true);
    for (final ambient in HistoryAmbientVariant.values) {
      await tester.tap(
        find.text(switch (ambient) {
          HistoryAmbientVariant.chronoArchive => 'A CHRONO',
          HistoryAmbientVariant.dataVault => 'B VAULT',
          HistoryAmbientVariant.memoryStream => 'C STREAM',
        }),
      );
      await tester.pump();
      await expectLater(
        find.byKey(ValueKey('history-ambient-${ambient.name}')),
        matchesGoldenFile('goldens/history_ambient_${ambient.name}_start.png'),
      );
      await tester.pump(const Duration(seconds: 9));
      await expectLater(
        find.byKey(ValueKey('history-ambient-${ambient.name}')),
        matchesGoldenFile(
          'goldens/history_ambient_${ambient.name}_quarter.png',
        ),
      );
      await tester.pump(const Duration(seconds: 27));
      await expectLater(
        find.byKey(ValueKey('history-ambient-${ambient.name}')),
        matchesGoldenFile('goldens/history_ambient_${ambient.name}_loop.png'),
      );
    }
  });

  testWidgets('renders DATA VAULT corridor at the required animation phases', (
    tester,
  ) async {
    const phases = <(String, Duration)>[
      ('0', Duration.zero),
      ('25', Duration(seconds: 9)),
      ('50', Duration(seconds: 18)),
      ('75', Duration(seconds: 27)),
      ('999', Duration(milliseconds: 35964)),
    ];

    for (final phase in phases) {
      await pumpHistory(tester, animateAmbient: true);
      await tester.tap(find.text('B VAULT'));
      await tester.pump();
      if (phase.$2 != Duration.zero) await tester.pump(phase.$2);
      await expectLater(
        find.byKey(const ValueKey('history-ambient-dataVault')),
        matchesGoldenFile(
          'goldens/history_data_vault_v13_phase_${phase.$1}.png',
        ),
      );
    }
  });
}
