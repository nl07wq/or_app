import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_configuration.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_editor_page.dart';
import 'package:or_app/features/themes/base_camp/base_camp_soldier_motion.dart';
import 'package:or_app/features/themes/base_camp/soldier_live_motion_preview_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('approved soldier transform is the production shared reference', () {
    expect(baseCampApprovedRifleGlobalX, -0.9999618530273438);
    expect(baseCampApprovedRifleGlobalY, 5.3333892822265625);
    expect(baseCampApprovedRifleGlobalScale, 0.9773123770508106);
    expect(baseCampApprovedRifleFrameOffsets, const <Offset>[
      Offset(-13.5, 46.5),
      Offset(-14, 47),
      Offset(-30.5, 46),
      Offset(-13.5, 25.5),
      Offset(-13, 44.5),
      Offset(-20, 46),
    ]);
    expect(baseCampApprovedRifleFrameScales, const <double>[
      1.15,
      1.15,
      1.15,
      1.15,
      1.2,
      1.2,
    ]);

    final transform = baseCampRifleRegripTransform(const Size(320, 240), 4);
    final explicit = baseCampRifleRegripTransform(
      const Size(320, 240),
      4,
      globalX: baseCampApprovedRifleGlobalX,
      globalY: baseCampApprovedRifleGlobalY,
      globalScale: baseCampApprovedRifleGlobalScale,
      frameOffsets: baseCampApprovedRifleFrameOffsets,
      frameScales: baseCampApprovedRifleFrameScales,
    );
    expect(transform.left, explicit.left);
    expect(transform.top, explicit.top);
    expect(transform.dimension, explicit.dimension);
  });

  testWidgets('live preview runs every regrip phase and returns to breathing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: SoldierLiveMotionPreviewPage()),
    );
    await tester.pump();

    expect(find.text('PHASE: BREATHING'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('base-camp-soldier-lower')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('soldier-live-trigger-regrip')));
    await tester.pump();
    expect(find.text('PHASE: PREIDLE'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1001));
    expect(find.text('PHASE: RIFLEREGRIP'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('soldier-live-rifle-frame-0')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1850));
    expect(find.text('PHASE: POSTIDLE'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('soldier-live-rifle-frame-5')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('PHASE: BREATHING'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('base-camp-soldier-lower')),
      findsOneWidget,
    );
  });

  testWidgets('water editor creates, saves and restores a fifth area', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    baseCampMapConfigurationController.resetForTesting(
      BaseCampMapConfiguration.defaults(),
    );
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: BaseCampMapEditorPage()));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('WATER MASK'));
    await tester.pump();
    final newArea = find.byKey(
      const ValueKey('base-camp-editor-water-new-area'),
    );
    await tester.ensureVisible(newArea);
    await tester.tap(newArea);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('base-camp-editor-water-placement-ready')),
      findsOneWidget,
    );

    final placement = find.byKey(
      const ValueKey('base-camp-editor-water-new-area-canvas'),
    );
    await tester.tapAt(tester.getCenter(placement));
    await tester.pump();
    expect(find.text('SELECT AREA 5'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('base-camp-editor-save')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      baseCampMapConfigurationController.value.waterFx['water']!.effectiveAreas,
      hasLength(5),
    );

    final restored = BaseCampMapConfigurationController();
    await restored.load();
    expect(restored.value.waterFx['water']!.effectiveAreas, hasLength(5));
  });
}
