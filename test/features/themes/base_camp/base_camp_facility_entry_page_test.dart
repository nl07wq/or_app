import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/core/widgets/operation_button.dart';
import 'package:or_app/features/activity/activity_page.dart';
import 'package:or_app/features/activity/widgets/activity_ambient_kinetic_field.dart';
import 'package:or_app/features/command_center/pages/command_center_page.dart';
import 'package:or_app/features/command_center/widgets/command_center_ambient_processing.dart';
import 'package:or_app/features/food/food_page.dart';
import 'package:or_app/features/food/widgets/food_feature_chrome.dart';
import 'package:or_app/features/morning/morning_page.dart';
import 'package:or_app/features/morning/widgets/status_radial_spectrum_ambient.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/themes/base_camp/base_camp_facility_entry_page.dart';
import 'package:or_app/features/themes/base_camp/base_camp_presentation.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_map.dart';
import 'package:or_app/features/training/training_page.dart';
import 'package:or_app/features/training/widgets/training_ambient_comparison.dart';

import '../../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../../operation_date/operation_date_test_fixture.dart';

void main() {
  setUp(() {
    final database = FakeIndexedDbDatabase();
    seedOperationState(database, '2026-11-13');
    final controller = AppInitializationController()..markReady();
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  test(
    'facility assets retain the supplied names and 16:9 dimensions',
    () async {
      for (final asset in <String>[
        baseCampStatusEntryAsset,
        baseCampActivityEntryAsset,
        baseCampFoodEntryAsset,
        baseCampTrainingEntryAsset,
        baseCampCommandCenterEntryAsset,
      ]) {
        final bytes = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 1536, reason: asset);
        expect(frame.image.height, 864, reason: asset);
        frame.image.dispose();
        codec.dispose();
      }
    },
  );

  test('walker frames use one bounded shared decode contract', () {
    expect(baseCampWalkerWarmupAssets, hasLength(25));
    expect(baseCampWalkerWarmupAssets.toSet(), hasLength(25));
    final provider = baseCampWalkerFrameProvider(
      baseCampWalkerWarmupAssets.first,
    );
    expect(provider, isA<ResizeImage>());
    expect((provider as ResizeImage).height, baseCampWalkerDecodeHeight);
  });

  testWidgets('BASE CAMP replaces all four module ambient entry surfaces', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpBaseCamp(tester, BaseCampScreen.morning, const MorningPage());
    expect(_facilityEntry('status'), findsOneWidget);
    expect(find.text('STATUS ENTRY'), findsOneWidget);
    expect(find.textContaining('BASE CAMP //'), findsNothing);
    expect(find.text('SCHEDULE'), findsOneWidget);
    expect(find.text('RECORD'), findsOneWidget);
    expect(find.byType(StatusAmbientBackground), findsNothing);

    await _pumpBaseCamp(tester, BaseCampScreen.activity, const ActivityPage());
    expect(_facilityEntry('activity'), findsOneWidget);
    expect(find.text('ACTIVITY ENTRY'), findsOneWidget);
    expect(find.text('RECORD'), findsOneWidget);
    expect(find.byType(ActivityAmbientBackground), findsNothing);

    await _pumpBaseCamp(tester, BaseCampScreen.food, const FoodPage());
    expect(_facilityEntry('food'), findsOneWidget);
    expect(find.text('FOOD ENTRY'), findsOneWidget);
    expect(find.text('RECORD'), findsOneWidget);
    expect(find.text('FOOD DATABASE'), findsOneWidget);
    expect(find.text('SYNC FOOD'), findsOneWidget);
    expect(find.byType(FoodFeatureScaffold), findsNothing);

    await _pumpBaseCamp(tester, BaseCampScreen.training, const TrainingPage());
    expect(_facilityEntry('training'), findsOneWidget);
    expect(find.text('TRAINING ENTRY'), findsOneWidget);
    expect(find.text('PLAN'), findsOneWidget);
    expect(find.text('RECORD'), findsOneWidget);
    expect(find.text('ANALYSIS REPORT'), findsOneWidget);
    expect(find.text('SYNC TRAINING'), findsOneWidget);
    expect(find.byType(TrainingAmbientComparison), findsNothing);
  });

  testWidgets('COMMAND CENTER entry reaches the existing tab workspace', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpBaseCamp(
      tester,
      BaseCampScreen.commandCenter,
      const CommandCenterPage(),
    );

    expect(_facilityEntry('command center'), findsOneWidget);
    expect(find.text('PERIODIC REPORT'), findsOneWidget);
    expect(find.text('BRIEF / DEBRIEF'), findsOneWidget);
    expect(find.text('DAILY COMMAND'), findsOneWidget);
    expect(find.text('DATA CENTER'), findsOneWidget);
    expect(find.byType(CommandCenterAmbientProcessing), findsNothing);

    final orderedButtons = tester
        .widgetList<OperationButton>(find.byType(OperationButton))
        .map((button) => button.text)
        .toList(growable: false);
    expect(orderedButtons, [
      'DAILY COMMAND',
      'BRIEF / DEBRIEF',
      'PERIODIC REPORT',
      'DATA CENTER',
    ]);

    final dataCenterButton = tester.widget<OperationButton>(
      find.widgetWithText(OperationButton, 'DATA CENTER'),
    );
    expect(dataCenterButton.onPressed, isNotNull);
    dataCenterButton.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('command-center-presentation-stack')),
      findsOneWidget,
    );
    expect(find.byType(CommandCenterAmbientProcessing), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'facility image stays fixed while only the safe-area menu scrolls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final actions = List<BaseCampFacilityEntryAction>.generate(
        5,
        (index) => BaseCampFacilityEntryAction(
          description: 'MENU DESCRIPTION $index',
          child: OperationButton(text: 'MENU $index', onPressed: () {}),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 480),
              padding: EdgeInsets.only(bottom: 34),
            ),
            child: BaseCampFacilityEntryPage(
              title: 'TEST',
              imageAsset: baseCampStatusEntryAsset,
              actions: actions,
            ),
          ),
        ),
      );
      await tester.pump();

      final image = find.byKey(const ValueKey('base-camp-facility-image-TEST'));
      final menu = find.byKey(
        const ValueKey('base-camp-test-facility-menu-scroll'),
      );
      final scrollable = find.descendant(
        of: menu,
        matching: find.byType(Scrollable),
      );
      final initialImageRect = tester.getRect(image);
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.pixels, 0);
      expect(position.maxScrollExtent, greaterThan(0));

      await tester.drag(image, const Offset(0, -120));
      await tester.pump();
      expect(position.pixels, 0);
      expect(tester.getRect(image), initialImageRect);

      await tester.drag(menu, const Offset(0, -120));
      await tester.pump();
      expect(position.pixels, greaterThan(0));
      expect(tester.getRect(image), initialImageRect);

      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      final lastButton = find.widgetWithText(OperationButton, 'MENU 4');
      expect(lastButton, findsOneWidget);
      expect(tester.getRect(lastButton).bottom, lessThanOrEqualTo(480 - 34));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all five entries use the isolated facility menu scroll', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cases = <(BaseCampScreen, Widget, String)>[
      (BaseCampScreen.morning, const MorningPage(), 'status'),
      (BaseCampScreen.activity, const ActivityPage(), 'activity'),
      (BaseCampScreen.food, const FoodPage(), 'food'),
      (BaseCampScreen.training, const TrainingPage(), 'training'),
      (
        BaseCampScreen.commandCenter,
        const CommandCenterPage(),
        'command center',
      ),
    ];

    for (final (screen, page, title) in cases) {
      await _pumpBaseCamp(tester, screen, page);
      final image = find.byKey(
        ValueKey('base-camp-facility-image-${title.toUpperCase()}'),
      );
      final menu = find.byKey(
        ValueKey('base-camp-$title-facility-menu-scroll'),
      );
      expect(image, findsOneWidget, reason: title);
      expect(menu, findsOneWidget, reason: title);
      final imageRect = tester.getRect(image);
      final scrollable = find.descendant(
        of: menu,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.pixels, 0, reason: title);
      expect(imageRect.width, closeTo(288, .1), reason: title);
      expect(imageRect.height, closeTo(132, .1), reason: title);
      if (position.maxScrollExtent > 0) {
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
      }
      expect(tester.getRect(image), imageRect, reason: title);
      final buttons = find.descendant(
        of: menu,
        matching: find.byType(OperationButton),
      );
      expect(buttons, findsAtLeastNWidgets(2), reason: title);
      expect(
        tester.getRect(buttons.last).bottom,
        lessThanOrEqualTo(480),
        reason: title,
      );
      expect(tester.takeException(), isNull, reason: title);
    }
  });

  testWidgets('COMMAND CENTER reordered actions retain their destinations', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const destinations = <(String, CommandCenterSection)>[
      ('DAILY COMMAND', CommandCenterSection.dailyCommand),
      ('BRIEF / DEBRIEF', CommandCenterSection.briefDebrief),
      ('PERIODIC REPORT', CommandCenterSection.periodicReport),
      ('DATA CENTER', CommandCenterSection.dataCenter),
    ];

    for (final (label, section) in destinations) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await _pumpBaseCamp(
        tester,
        BaseCampScreen.commandCenter,
        const CommandCenterPage(),
      );
      final button = tester.widget<OperationButton>(
        find.widgetWithText(OperationButton, label),
      );
      expect(button.onPressed, isNotNull, reason: label);
      button.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final destination = tester.widget<CommandCenterPage>(
        find.byType(CommandCenterPage).last,
      );
      expect(destination.showBaseCampEntry, isFalse, reason: label);
      expect(destination.initialSection, section, reason: label);
      expect(tester.takeException(), isNull, reason: label);
    }
  });

  testWidgets('STANDARD module presentation remains unchanged', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FoodPage()));
    await tester.pump();

    expect(find.byType(FoodFeatureScaffold), findsOneWidget);
    expect(find.byType(BaseCampFacilityEntryPage), findsNothing);
  });
}

Finder _facilityEntry(String title) =>
    find.byKey(ValueKey('base-camp-$title-facility-entry'));

Future<void> _pumpBaseCamp(
  WidgetTester tester,
  BaseCampScreen screen,
  Widget child,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BaseCampScreenEntry(screen: screen, child: child),
    ),
  );
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump();
}
