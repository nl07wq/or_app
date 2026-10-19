import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/theme/app_theme.dart';
import 'package:or_app/features/body_history/pages/data_center_history_page.dart';
import 'package:or_app/features/body_history/services/history_visual_preference.dart';
import 'package:or_app/features/body_history/widgets/history_data_vault_hyperspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpHistory(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    bool animateAmbient = false,
    Duration dataVaultSimulationTime = Duration.zero,
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
        home: DataCenterHistoryPage(
          animateAmbient: animateAmbient,
          dataVaultSimulationTime: dataVaultSimulationTime,
        ),
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
      ('cruise_0', Duration.zero),
      ('cruise_7', Duration(seconds: 7)),
      ('cruise_13', Duration(seconds: 13)),
      ('sprint_16', Duration(seconds: 16)),
      ('sprint_20', Duration(seconds: 20)),
      ('sprint_24', Duration(seconds: 24)),
      ('corner_27', Duration(seconds: 27)),
      ('corner_32', Duration(seconds: 32)),
      ('corner_37', Duration(seconds: 37)),
      ('return_42', Duration(seconds: 42)),
      ('return_4799', Duration(milliseconds: 47990)),
      ('return_4801', Duration(milliseconds: 48010)),
    ];

    for (final phase in phases) {
      await pumpHistory(tester, dataVaultSimulationTime: phase.$2);
      await tester.tap(find.text('B VAULT'));
      await tester.pump();
      if (phase.$2 != Duration.zero) await tester.pump(phase.$2);
      await expectLater(
        find.byKey(const ValueKey('history-ambient-dataVault')),
        matchesGoldenFile(
          'goldens/history_data_vault_v14_phase_${phase.$1}.png',
        ),
      );
    }
  });

  test('DATA VAULT motion is monotonic with smooth periodic speed', () {
    expect(HistoryDataVaultMotion.speedAt(0), 4);
    expect(HistoryDataVaultMotion.speedAt(12), 4);
    expect(HistoryDataVaultMotion.speedAt(17), 11);
    expect(HistoryDataVaultMotion.speedAt(22), 11);
    expect(HistoryDataVaultMotion.speedAt(27), 7);
    expect(HistoryDataVaultMotion.speedAt(36), 7);
    expect(HistoryDataVaultMotion.speedAt(42), 4);
    expect(HistoryDataVaultMotion.speedAt(48), 4);
    for (final transition in [0.0, 12.0, 17.0, 22.0, 27.0, 36.0, 42.0, 48.0]) {
      expect(
        (HistoryDataVaultMotion.speedAt(transition - .001) -
                HistoryDataVaultMotion.speedAt(transition + .001))
            .abs(),
        lessThan(.001),
      );
    }
    for (final boundary in [40.0, 105.0, 130.0, 195.0, 240.0]) {
      expect(
        (HistoryDataVaultMotion.curvatureAt(boundary - .001) -
                HistoryDataVaultMotion.curvatureAt(boundary + .001))
            .abs(),
        lessThan(.001),
      );
    }
    for (var second = 0; second < 240; second++) {
      expect(
        HistoryDataVaultMotion.distanceAt((second + 1).toDouble()),
        greaterThan(HistoryDataVaultMotion.distanceAt(second.toDouble())),
      );
    }
    expect(
      HistoryDataVaultMotion.distanceAt(48),
      closeTo(HistoryDataVaultMotion.distancePerCycle, .0001),
    );
    expect(
      HistoryDataVaultMotion.distanceAt(48.01),
      greaterThan(HistoryDataVaultMotion.distanceAt(48)),
    );
  });
}
