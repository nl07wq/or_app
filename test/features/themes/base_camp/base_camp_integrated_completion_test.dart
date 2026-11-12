import 'dart:async';

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
    expect(baseCampApprovedRifleGlobalY, -1.3513513513514113);
    expect(baseCampApprovedRifleGlobalScale, 0.9617116773450697);
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

  test('axis scaling preserves the visible foot center anchor', () {
    const viewport = Size(320, 240);
    final normal = baseCampRifleRegripTransform(viewport, 4);
    final stretched = baseCampRifleRegripTransform(
      viewport,
      4,
      verticalScaleX: 1.3,
      horizontalScaleY: .7,
    );
    expect(
      stretched.left + stretched.width / 2,
      closeTo(normal.left + normal.width / 2, .0001),
    );
    expect(
      stretched.top + stretched.height,
      closeTo(normal.top + normal.height, .0001),
    );
    expect(stretched.height, closeTo(normal.height * 1.3, .0001));
    expect(stretched.width, closeTo(normal.width * .7, .0001));
  });

  test(
    'v2 persistence keeps saved values and defaults missing axis scales',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = BaseCampRifleAlignmentController();
      final saved = BaseCampRifleGlobalAlignment(
        x: 4,
        y: -3,
        scale: 1.1,
        verticalScaleX: 1.2,
        horizontalScaleY: .8,
        frameOffsets: const <Offset>[
          Offset(1, 2),
          Offset(3, 4),
          Offset(5, 6),
          Offset(7, 8),
          Offset(9, 10),
          Offset(11, 12),
        ],
        frameScales: const <double>[1, 1.1, 1.2, 1.3, 1.4, 1.5],
        brightness: .1,
        contrast: .9,
        saturation: .8,
        warmth: -.1,
        frameDurationsMs: const <int>[410, 360, 210, 340, 160, 420],
      );
      await controller.save(saved);

      final restored = BaseCampRifleAlignmentController();
      await restored.load();
      expect(restored.value.x, 4);
      expect(restored.value.verticalScaleX, 1.2);
      expect(restored.value.horizontalScaleY, .8);
      expect(restored.value.frameOffsets[5], const Offset(11, 12));
      expect(restored.value.frameScales[4], 1.4);
      expect(restored.value.frameDurationsMs, [410, 360, 210, 340, 160, 420]);

      final legacy = Map<String, Object?>.of(saved.toJson());
      final legacyAlignment =
          Map<String, Object?>.of(legacy['alignment']! as Map<String, Object?>)
            ..remove('scaleXVertical')
            ..remove('scaleYHorizontal');
      legacy['alignment'] = legacyAlignment;
      final compatible = BaseCampRifleGlobalAlignment.fromJson(legacy);
      expect(compatible.verticalScaleX, 1);
      expect(compatible.horizontalScaleY, 1);
    },
  );

  testWidgets('live preview runs every regrip phase and returns to breathing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    baseCampRifleGlobalAlignment.resetForTesting();
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
    expect(find.text('SCALE X — VERTICAL'), findsOneWidget);
    expect(find.text('SCALE Y — HORIZONTAL'), findsOneWidget);
  });

  testWidgets('failed APPLY retains editor values and does not publish', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = BaseCampRifleAlignmentController(
      storageWriter: (_, _, _) async => false,
    );
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: SoldierLiveMotionPreviewPage(alignmentController: controller),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final globalXRow = find.ancestor(
      of: find.text('GLOBAL X'),
      matching: find.byType(Row),
    );
    final sliderFinder = find.descendant(
      of: globalXRow,
      matching: find.byType(Slider),
    );
    tester.widget<Slider>(sliderFinder).onChanged!(12);
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('soldier-live-apply-dashboard')),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('APPLY FAILED — EDITED VALUES RETAINED'), findsOneWidget);
    expect(tester.widget<Slider>(sliderFinder).value, 12);
    expect(controller.value.x, baseCampApprovedRifleGlobalX);
  });

  testWidgets(
    'existing static soldiers select, cancel, edit, delete, undo and persist',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final configuration = BaseCampMapConfiguration.defaults().copyWith(
        staticSoldiers: const <BaseCampStaticSoldier>[
          BaseCampStaticSoldier(
            id: 'guard-1',
            position: Offset(640, 360),
            scale: .6,
          ),
          BaseCampStaticSoldier(
            id: 'guard-2',
            position: Offset(760, 420),
            scale: .7,
          ),
        ],
      );
      final controller = BaseCampMapConfigurationController()
        ..resetForTesting(configuration);
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
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('STATIC SOLDIER'));
      await tester.pump();

      final guard1 = find.byKey(
        const ValueKey('base-camp-static-soldier-handle-guard-1'),
      );
      final guard2 = find.byKey(
        const ValueKey('base-camp-static-soldier-handle-guard-2'),
      );
      await tester.tap(guard1);
      await tester.pump();
      expect(find.text('DELETE'), findsOneWidget);
      expect(find.text('SELECTED: guard-1'), findsOneWidget);

      var scaleSlider = tester.widgetList<Slider>(find.byType(Slider)).first;
      scaleSlider.onChanged!(.9);
      await tester.pump();
      await tester.tap(find.byTooltip('Cancel unsaved changes'));
      await tester.pump();
      await tester.tap(find.text('DISCARD'));
      await tester.pump();

      await tester.tap(guard1);
      await tester.pump();
      scaleSlider = tester.widgetList<Slider>(find.byType(Slider)).first;
      expect(scaleSlider.value, closeTo(.6, .001));
      scaleSlider.onChanged!(.8);
      await tester.pump();

      await tester.tap(guard2);
      await tester.pump();
      await tester.tap(find.text('DELETE'));
      await tester.pump();
      expect(guard2, findsNothing);
      await tester.tap(find.byKey(const ValueKey('base-camp-editor-undo')));
      await tester.pump();
      expect(guard2, findsOneWidget);
      await tester.tap(guard2);
      await tester.pump();
      await tester.tap(find.text('DELETE'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('base-camp-editor-save')));
      await tester.pump(const Duration(milliseconds: 150));

      expect(controller.value.staticSoldiers, hasLength(1));
      expect(controller.value.staticSoldiers.single.id, 'guard-1');
      expect(controller.value.staticSoldiers.single.scale, closeTo(.8, .001));
      final restored = BaseCampMapConfigurationController();
      await restored.load();
      expect(restored.value.staticSoldiers, hasLength(1));
      expect(restored.value.staticSoldiers.single.id, 'guard-1');
    },
  );

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
      find.byKey(const ValueKey('base-camp-editor-ambient-preview-boundary')),
      findsOneWidget,
    );
    expect(find.text('BASE CAMP MAP EDITOR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('water editor omits retired FX controls and keeps mask tools', (
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
    expect(find.text('FX PARAMETERS'), findsNothing);
    expect(find.text('SHIMMER'), findsNothing);
    expect(find.text('RIPPLE'), findsNothing);
    expect(find.text('FOAM'), findsNothing);
    expect(find.text('WATER MASK'), findsOneWidget);
    expect(find.text('SHORELINE'), findsOneWidget);
    expect(find.text('EXCLUSION MASK'), findsOneWidget);
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
