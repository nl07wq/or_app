import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/soldier_alignment_sandbox.dart';
import 'package:or_app/features/themes/base_camp/base_camp_dashboard_page.dart';

void main() {
  test('sandbox starts from the approved production alignment', () {
    const data = SoldierAlignmentData();
    expect(data.offsetXdp, baseCampApprovedRifleGlobalX);
    expect(data.offsetYdp, baseCampApprovedRifleGlobalY);
    expect(data.scale, baseCampApprovedRifleGlobalScale);
    expect(data.frameOffsets, baseCampApprovedRifleFrameOffsets);
    expect(data.frameScales, baseCampApprovedRifleFrameScales);
  });

  test('alignment data round-trips and rejects invalid frame contracts', () {
    const source = SoldierAlignmentData(
      frameOffsets: [
        Offset.zero,
        Offset(1, -.5),
        Offset(-1, .5),
        Offset.zero,
        Offset.zero,
        Offset.zero,
      ],
      frameScales: [1, 1, 1, 1, 1.25, .8],
      offsetXdp: 4,
      offsetYdp: -2,
      scale: 1.05,
      brightness: .1,
      contrast: 1.1,
      saturation: .9,
      warmth: 3,
    );
    final restored = SoldierAlignmentData.tryParse(
      source.toJson(
        const Size(320, 320),
        settings: const SoldierAlignmentPreviewSettings(
          selectedFrame: 4,
          comparisonFrame: 5,
          useCorrectedAssets: false,
          showBeforeColor: true,
          transitionPreview: true,
          transitionLoop: false,
        ),
      ),
    );
    expect(restored, isNotNull);
    expect(restored!.frameOffsets[1], const Offset(1, -.5));
    expect(restored.frameScales[4], 1.25);
    expect(restored.scale, 1.05);
    final invalid = source.toJson(const Size(320, 320))
      ..['frameOffsetsPx'] = [];
    expect(SoldierAlignmentData.tryParse(invalid), isNull);
  });

  test(
    'alignment document keeps preview settings and accepts legacy v2 JSON',
    () {
      const source = SoldierAlignmentData(
        frameOffsets: [
          Offset(-256, 256),
          Offset.zero,
          Offset.zero,
          Offset.zero,
          Offset.zero,
          Offset.zero,
        ],
        frameScales: [1, 1, 1, 1, 1.5, .5],
      );
      final json = source.toJson(
        const Size(300, 300),
        settings: const SoldierAlignmentPreviewSettings(
          selectedFrame: 5,
          comparisonFrame: 4,
          showGrid: false,
          transitionPreview: true,
          transitionLoop: false,
        ),
      );
      final document = SoldierAlignmentData.tryParseDocument(json);
      expect(document, isNotNull);
      expect(document!.settings.selectedFrame, 5);
      expect(document.settings.showGrid, isFalse);
      expect(document.settings.transitionPreview, isTrue);
      expect(document.settings.transitionLoop, isFalse);
      expect(document.data.frameScales[4], 1.5);

      final legacy = source.toJson(const Size(300, 300))..remove('preview');
      for (final frame in legacy['frameOffsetsPx']! as List<Object?>) {
        (frame as Map<Object?, Object?>).remove('scale');
      }
      final restoredLegacy = SoldierAlignmentData.tryParseDocument(legacy);
      expect(restoredLegacy, isNotNull);
      expect(restoredLegacy!.data.frameScales, everyElement(1));

      final invalid = source.toJson(const Size(300, 300))
        ..['preview'] = {'showGrid': 'not-a-bool'};
      expect(SoldierAlignmentData.tryParseDocument(invalid), isNull);
    },
  );

  test('grid uses one square logical plane with a uniform viewport scale', () {
    final sandbox = baseCampSoldierGridGeometryForViewport(
      const Size(360, 360),
    );
    final dashboard = baseCampSoldierGridGeometryForViewport(
      const Size(140, 98),
    );
    expect(sandbox.logicalSize.height, dashboard.logicalSize.height);
    expect(sandbox.scale, 1);
    expect(dashboard.scale, closeTo(98 / 360, .0001));
    expect(dashboard.logicalSize.width * dashboard.scale, closeTo(140, .001));
    expect(
      baseCampSoldierWallGridSpacing * dashboard.scale,
      closeTo(32 * dashboard.scale, .0001),
    );
  });

  test('global alignment preserves every frame-local correction', () {
    const data = SoldierAlignmentData(
      frameOffsets: [
        Offset(-13.5, 46.5),
        Offset(-14, 47),
        Offset(-30.5, 46),
        Offset(-13.5, 25.5),
        Offset(-13, 44.5),
        Offset(-20, 46),
      ],
      frameScales: [1.15, 1.15, 1.15, 1.15, 1.2, 1.2],
    );
    final globallyAligned = data.copyWith(
      offsetXdp: 12.5,
      offsetYdp: -8,
      scale: 1.05,
    );
    expect(globallyAligned.frameOffsets, data.frameOffsets);
    expect(globallyAligned.frameScales, data.frameScales);
    final resetGlobal = globallyAligned.copyWith(
      offsetXdp: 0,
      offsetYdp: 0,
      scale: 1,
    );
    expect(resetGlobal.frameOffsets, data.frameOffsets);
    expect(resetGlobal.frameScales, data.frameScales);
  });

  test('transition preview timing retains the production event sequence', () {
    expect(baseCampRifleRegripEventMs, 3850);
    expect(baseCampRifleRegripPhase(0), BaseCampRifleRegripPhase.preIdle);
    expect(baseCampRifleRegripPhase(999), BaseCampRifleRegripPhase.preIdle);
    expect(baseCampRifleRegripFrameIndex(1000), 0);
    expect(baseCampRifleRegripFrameIndex(1400), 1);
    expect(baseCampRifleRegripFrameIndex(1750), 2);
    expect(baseCampRifleRegripFrameIndex(1950), 3);
    expect(baseCampRifleRegripFrameIndex(2300), 4);
    expect(baseCampRifleRegripFrameIndex(2450), 5);
    expect(baseCampRifleRegripPhase(2850), BaseCampRifleRegripPhase.postIdle);
    expect(baseCampRifleRegripPhase(3850), BaseCampRifleRegripPhase.breathing);
  });

  testWidgets(
    'alignment sandbox exposes independent layer controls and copy/import',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SoldierAlignmentSandboxSection(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('SOLDIER ALIGNMENT'), findsOneWidget);
      expect(find.text('BREATHING'), findsOneWidget);
      expect(find.text('RIFLE REGRIP'), findsOneWidget);
      expect(find.text('TACTICAL GRID'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('copy-soldier-alignment-data')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('import-soldier-alignment-data')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
