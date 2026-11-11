import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_configuration.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_editor_page.dart';
import 'package:or_app/features/themes/base_camp/base_camp_soldier_motion.dart';
import 'package:or_app/features/themes/base_camp/soldier_live_motion_preview_page.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_map.dart';
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

  testWidgets('water draft restores without publishing until formal save', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final formal = BaseCampMapConfiguration.defaults();
    final effect = formal.waterFx['water']!;
    const fifth = BaseCampWaterArea(
      mask: <Offset>[Offset(500, 500), Offset(620, 500), Offset(620, 620)],
      shoreline: <Offset>[Offset(500, 560), Offset(620, 560)],
    );
    final draftConfiguration = formal.copyWith(
      waterFx: <String, BaseCampWaterFx>{
        'water': effect.copyWith(
          areas: <BaseCampWaterArea>[...effect.effectiveAreas, fifth],
        ),
      },
    );
    final controller = BaseCampMapConfigurationController();
    controller.resetForTesting(formal);
    final draftStore = BaseCampWaterDraftStore();
    await draftStore.save(draftConfiguration);
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: BaseCampMapEditorPage(
          configurationController: controller,
          waterDraftStore: draftStore,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('RECOVER WATER EDITS?'), findsOneWidget);
    await tester.tap(find.text('RESTORE'));
    await tester.pump();
    await tester.tap(find.text('WATER MASK'));
    await tester.pump();

    final restoredSelector = tester.widget<DropdownButton<int>>(
      find.byKey(const ValueKey('base-camp-editor-water-select-area')),
    );
    expect(restoredSelector.items, hasLength(5));
    expect(controller.value.waterFx['water']!.effectiveAreas, hasLength(4));

    await tester.tap(find.byKey(const ValueKey('base-camp-editor-save')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(controller.value.waterFx['water']!.effectiveAreas, hasLength(5));
    expect((await draftStore.load()).state, BaseCampWaterDraftState.missing);
  });

  testWidgets(
    'abnormal editor disposal leaves an auto-saved restorable draft',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = BaseCampMapConfigurationController()
        ..resetForTesting(BaseCampMapConfiguration.defaults());
      final draftStore = BaseCampWaterDraftStore();
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Widget editor() => MaterialApp(
        home: BaseCampMapEditorPage(
          configurationController: controller,
          waterDraftStore: draftStore,
        ),
      );

      await tester.pumpWidget(editor());
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('WATER MASK'));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('base-camp-editor-water-new-area')),
      );
      await tester.pump();
      await tester.tapAt(
        tester.getCenter(
          find.byKey(const ValueKey('base-camp-editor-water-new-area-canvas')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect((await draftStore.load()).state, BaseCampWaterDraftState.ready);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(controller.value.waterFx['water']!.effectiveAreas, hasLength(4));

      await tester.pumpWidget(editor());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('RECOVER WATER EDITS?'), findsOneWidget);
      await tester.tap(find.text('RESTORE'));
      await tester.pump();
      await tester.tap(find.text('WATER MASK'));
      await tester.pump();
      final selector = tester.widget<DropdownButton<int>>(
        find.byKey(const ValueKey('base-camp-editor-water-select-area')),
      );
      expect(selector.items, hasLength(5));
      expect(controller.value.waterFx['water']!.effectiveAreas, hasLength(4));
    },
  );

  testWidgets('failed formal save retains both edit state and water draft', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    var loaderCalls = 0;
    final controller = BaseCampMapConfigurationController(
      preferencesLoader: () async {
        loaderCalls++;
        if (loaderCalls > 1) throw StateError('formal storage denied');
        return preferences;
      },
    );
    final draftStore = BaseCampWaterDraftStore();
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BaseCampMapEditorPage(
          configurationController: controller,
          waterDraftStore: draftStore,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('WATER MASK'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('base-camp-editor-water-new-area')),
    );
    await tester.pump();
    final canvas = find.byKey(
      const ValueKey('base-camp-editor-water-new-area-canvas'),
    );
    await tester.tapAt(tester.getCenter(canvas));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const ValueKey('base-camp-editor-save')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text('SAVE FAILED — EDITS AND WATER DRAFT RETAINED'),
      findsOneWidget,
    );
    expect(find.text('SELECT AREA 5'), findsOneWidget);
    expect(controller.value.waterFx['water']!.effectiveAreas, hasLength(4));
    final draft = await draftStore.load();
    expect(draft.state, BaseCampWaterDraftState.ready);
    expect(draft.draft!.waterFx['water']!.effectiveAreas, hasLength(5));
  });

  testWidgets('formal save waits for an active water draft write', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = BaseCampMapConfigurationController()
      ..resetForTesting(BaseCampMapConfiguration.defaults());
    final draftStore = _BlockingWaterDraftStore();
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BaseCampMapEditorPage(
          configurationController: controller,
          waterDraftStore: draftStore,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('WATER MASK'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('base-camp-editor-water-new-area')),
    );
    await tester.pump();
    await tester.tapAt(
      tester.getCenter(
        find.byKey(const ValueKey('base-camp-editor-water-new-area-canvas')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(draftStore.writeStarted.isCompleted, isTrue);

    await tester.tap(find.byKey(const ValueKey('base-camp-editor-save')));
    await tester.pump();
    expect(controller.value.waterFx['water']!.effectiveAreas, hasLength(4));

    draftStore.allowWrite.complete();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.value.waterFx['water']!.effectiveAreas, hasLength(5));
    expect((await draftStore.load()).state, BaseCampWaterDraftState.missing);
  });

  testWidgets('cancel requires confirmation before discarding water draft', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = BaseCampMapConfigurationController()
      ..resetForTesting(BaseCampMapConfiguration.defaults());
    final draftStore = BaseCampWaterDraftStore();
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BaseCampMapEditorPage(
          configurationController: controller,
          waterDraftStore: draftStore,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('WATER MASK'));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('base-camp-editor-water-new-area')),
    );
    await tester.pump();
    await tester.tapAt(
      tester.getCenter(
        find.byKey(const ValueKey('base-camp-editor-water-new-area-canvas')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byTooltip('Cancel unsaved changes'));
    await tester.pump();
    expect(find.text('DISCARD UNSAVED EDITS?'), findsOneWidget);
    await tester.tap(find.text('KEEP EDITING'));
    await tester.pump();
    expect(find.text('SELECT AREA 5'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancel unsaved changes'));
    await tester.pump();
    await tester.tap(find.text('DISCARD'));
    await tester.pump(const Duration(milliseconds: 100));

    final selector = tester.widget<DropdownButton<int>>(
      find.byKey(const ValueKey('base-camp-editor-water-select-area')),
    );
    expect(selector.items, hasLength(4));
    expect((await draftStore.load()).state, BaseCampWaterDraftState.missing);
  });

  testWidgets('water area switching drag and pinch remain stable on mobile', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = BaseCampMapConfigurationController()
      ..resetForTesting(BaseCampMapConfiguration.defaults());
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BaseCampMapEditorPage(
          configurationController: controller,
          waterDraftStore: BaseCampWaterDraftStore(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('WATER MASK'));
    await tester.pump();

    final selector = find.byKey(
      const ValueKey('base-camp-editor-water-select-area'),
    );
    await tester.ensureVisible(selector);
    await tester.pump();
    await tester.tap(selector);
    await tester.pump();
    await tester.tap(find.text('SELECT AREA 4').last);
    await tester.pump();

    final handle = find.byKey(const ValueKey('base-camp-water-mask-point-20'));
    final drag = await tester.startGesture(tester.getCenter(handle));
    await drag.moveBy(const Offset(12, -8));
    await tester.pump();
    await drag.up();

    final map = find.byKey(const ValueKey('base-camp-editor-map'));
    final center = tester.getCenter(map);
    final first = await tester.startGesture(
      center - const Offset(20, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(20, 0),
      pointer: 2,
    );
    await first.moveTo(center - const Offset(80, 0));
    await second.moveTo(center + const Offset(80, 0));
    await tester.pump();
    await first.up();
    await second.up();

    for (var index = 1; index <= 4; index++) {
      await tester.ensureVisible(selector);
      await tester.pump();
      await tester.tap(selector);
      await tester.pump();
      await tester.tap(find.text('SELECT AREA $index').last);
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(seconds: 3));

    expect(
      find.byKey(const ValueKey('base-camp-editor-water-preview-boundary')),
      findsOneWidget,
    );
    expect(find.text('BASE CAMP MAP EDITOR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('water FX editor explains and isolates all three layers', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = BaseCampMapConfigurationController()
      ..resetForTesting(BaseCampMapConfiguration.defaults());
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: BaseCampMapEditorPage(
          configurationController: controller,
          waterDraftStore: BaseCampWaterDraftStore(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('FX PARAMETERS'));
    await tester.pump();

    for (final layer in const <String>['shimmer', 'ripple', 'foam']) {
      final chip = find.text(layer.toUpperCase());
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();
      expect(
        find.byKey(ValueKey('base-camp-water-fx-help-$layer')),
        findsOneWidget,
      );
      final fxLayer = tester.widget<BaseCampWaterFxLayer>(
        find.byType(BaseCampWaterFxLayer),
      );
      expect(fxLayer.previewLayer, layer);
    }
  });
}

class _BlockingWaterDraftStore extends BaseCampWaterDraftStore {
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> allowWrite = Completer<void>();

  @override
  Future<void> save(BaseCampMapConfiguration configuration) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await allowWrite.future;
    await super.save(configuration);
  }
}
