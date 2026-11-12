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
    expect(find.byType(CommandCenterAmbientProcessing), findsOneWidget);
    expect(tester.takeException(), isNull);
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
