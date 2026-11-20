import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_configuration.dart';
import 'package:or_app/features/themes/base_camp/base_camp_map_editor_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sectionLabels = <String>[
  'ROUTE EDITOR',
  'BUILDING EDITOR',
  'OBJECT EDITOR',
  'SMOKE ORIGIN',
  'FACILITY LABEL',
  'WATER MASK',
  'SHORELINE',
  'EXCLUSION MASK',
  'STATIC SOLDIER',
  'SOLDIER SIZE',
  'HELICOPTER',
];

Future<BaseCampMapConfigurationController> _pumpEditor(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = BaseCampMapConfigurationController()
    ..resetForTesting(BaseCampMapConfiguration.defaults());
  await tester.pumpWidget(
    MaterialApp(
      home: BaseCampMapEditorPage(configurationController: controller),
    ),
  );
  await tester.pump(const Duration(milliseconds: 250));
  return controller;
}

Future<void> _selectSection(WidgetTester tester, String label) async {
  final tab = find.text(label);
  await tester.ensureVisible(tab);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.tap(tab);
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('section navigation is one ordered horizontal row', (
    tester,
  ) async {
    await _pumpEditor(tester);

    final tabs = find.byKey(const ValueKey('base-camp-editor-section-tabs'));
    final tabsScroll = find.byKey(
      const ValueKey('base-camp-editor-section-tabs-scroll'),
    );
    expect(tester.getSize(tabs).height, 52);
    expect(
      tester.widget<SingleChildScrollView>(tabsScroll).scrollDirection,
      Axis.horizontal,
    );
    final chips = find.descendant(of: tabs, matching: find.byType(ChoiceChip));
    expect(chips, findsNWidgets(11));
    expect(
      tester
          .widgetList<Text>(
            find.descendant(of: tabs, matching: find.byType(Text)),
          )
          .map((text) => text.data)
          .whereType<String>()
          .toList(),
      _sectionLabels,
    );

    await _selectSection(tester, 'WATER MASK');
    final tabsController = tester
        .widget<SingleChildScrollView>(tabsScroll)
        .controller!;
    final waterOffset = tabsController.offset;
    expect(
      tester
          .widget<ChoiceChip>(
            find.ancestor(
              of: find.text('WATER MASK'),
              matching: find.byType(ChoiceChip),
            ),
          )
          .selected,
      isTrue,
    );
    final helicopterChip = find.ancestor(
      of: find.text('HELICOPTER'),
      matching: find.byType(ChoiceChip),
    );
    tester.widget<ChoiceChip>(helicopterChip).onSelected?.call(true);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.widget<ChoiceChip>(helicopterChip).selected, isTrue);
    expect(tabsController.offset, greaterThan(waterOffset));
    final tabsRect = tester.getRect(tabs);
    final helicopterRect = tester.getRect(find.text('HELICOPTER'));
    expect(helicopterRect.left, greaterThanOrEqualTo(tabsRect.left));
    expect(helicopterRect.right, lessThanOrEqualTo(tabsRect.right));
    expect(find.text('RUN FLIGHT'), findsOneWidget);

    await _selectSection(tester, 'ROUTE EDITOR');
    expect(
      tester
          .widget<ChoiceChip>(
            find.ancestor(
              of: find.text('ROUTE EDITOR'),
              matching: find.byType(ChoiceChip),
            ),
          )
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('workspace defaults to 35 percent and clamps both panels', (
    tester,
  ) async {
    await _pumpEditor(tester);
    final mapPane = find.byKey(const ValueKey('base-camp-editor-map-pane'));
    final controlsPane = find.byKey(
      const ValueKey('base-camp-editor-controls-pane'),
    );
    final handle = find.byKey(const ValueKey('base-camp-editor-resize-handle'));

    final initialMapHeight = tester.getSize(mapPane).height;
    final controlsHeight = tester.getSize(controlsPane).height;
    final handleHeight = tester.getSize(handle).height;
    final panelHeight = initialMapHeight + controlsHeight;
    expect(handleHeight, 24);
    expect(initialMapHeight / panelHeight, closeTo(.35, .01));

    await tester.drag(handle, const Offset(0, 10000));
    await tester.pump();
    expect(tester.getSize(controlsPane).height, closeTo(180, .01));
    expect(tester.getSize(mapPane).height, greaterThan(initialMapHeight));

    await tester.drag(handle, const Offset(0, -10000));
    await tester.pump();
    expect(tester.getSize(mapPane).height, closeTo(120, .01));
    expect(tester.getSize(controlsPane).height, greaterThan(controlsHeight));
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('base-camp-editor-undo')),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('resize preserves zoomed MAP center and controls scroll', (
    tester,
  ) async {
    await _pumpEditor(tester, size: const Size(430, 900));
    await _selectSection(tester, 'HELICOPTER');
    final map = find.byKey(const ValueKey('base-camp-editor-map'));
    final viewer = tester.widget<InteractiveViewer>(map);
    final transform = viewer.transformationController!;
    transform.value = Matrix4.identity()
      ..translateByDouble(-260, -180, 0, 1)
      ..scaleByDouble(1.4, 1.4, 1, 1);
    await tester.pump();

    final mapPane = find.byKey(const ValueKey('base-camp-editor-map-pane'));
    final oldMapSize = tester.getSize(mapPane);
    final oldCenterScene = transform.toScene(oldMapSize.center(Offset.zero));
    final controlsScroll = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('base-camp-editor-controls-scroll')),
    );
    final scrollController = controlsScroll.controller!;
    scrollController.jumpTo(
      scrollController.position.maxScrollExtent.clamp(0, 300),
    );
    final oldScrollOffset = scrollController.offset;
    await tester.pump();

    await tester.drag(
      find.byKey(const ValueKey('base-camp-editor-resize-handle')),
      const Offset(0, 80),
    );
    await tester.pump();
    await tester.pump();
    final newMapSize = tester.getSize(mapPane);
    final newCenterScene = transform.toScene(newMapSize.center(Offset.zero));
    expect(newCenterScene.dx, closeTo(oldCenterScene.dx, .01));
    expect(newCenterScene.dy, closeTo(oldCenterScene.dy, .01));
    expect(transform.value.getMaxScaleOnAxis(), closeTo(1.4, .001));
    expect(scrollController.offset, greaterThanOrEqualTo(oldScrollOffset));
    expect(find.text('RUN FLIGHT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short viewport and orientation changes remain bounded', (
    tester,
  ) async {
    await _pumpEditor(tester, size: const Size(320, 480));
    final mapPane = find.byKey(const ValueKey('base-camp-editor-map-pane'));
    final controlsPane = find.byKey(
      const ValueKey('base-camp-editor-controls-pane'),
    );
    expect(tester.getSize(mapPane).height, greaterThan(0));
    expect(tester.getSize(controlsPane).height, greaterThan(0));
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(844, 390));
    await tester.pump();
    await tester.pump();
    expect(tester.getSize(mapPane).height, greaterThan(0));
    expect(tester.getSize(controlsPane).height, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[320, 375, 390, 430]) {
    testWidgets('workspace remains operable at ${width.toInt()}dp', (
      tester,
    ) async {
      await _pumpEditor(tester, size: Size(width, 844));
      final tabs = find.byKey(const ValueKey('base-camp-editor-section-tabs'));
      final mapPane = find.byKey(const ValueKey('base-camp-editor-map-pane'));
      final controlsPane = find.byKey(
        const ValueKey('base-camp-editor-controls-pane'),
      );
      expect(tester.getSize(tabs).height, 52);
      expect(tester.getSize(mapPane).height, greaterThanOrEqualTo(120));
      expect(tester.getSize(controlsPane).height, greaterThanOrEqualTo(180));

      await _selectSection(tester, 'HELICOPTER');
      expect(find.text('RUN FLIGHT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
