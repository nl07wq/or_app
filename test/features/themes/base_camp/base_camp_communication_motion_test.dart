import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/themes/base_camp/base_camp_dashboard_page.dart'
    show BaseCampLcdGrainPainter;
import 'package:or_app/features/themes/base_camp/widgets/base_camp_communication_motion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(svg.cache.clear);

  testWidgets('all ten approved SVG assets load and compile', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(baseCampCommunicationAssets, hasLength(10));
    expect(baseCampCommunicationAssets.toSet(), hasLength(10));
    await tester.runAsync(() => prepareBaseCampCommunicationAssets(context));
    expect(svg.cache.count, 10);
    for (final asset in baseCampCommunicationAssets) {
      final source = await rootBundle.loadString(asset);
      expect(source, startsWith('<svg '), reason: asset);
      expect(source, contains('shape-rendering="crispEdges"'), reason: asset);
    }
    final idleArrow = await rootBundle.loadString(
      baseCampCommunicationArrowIdleAsset,
    );
    final activeArrow = await rootBundle.loadString(
      baseCampCommunicationArrowActiveAsset,
    );
    for (final arrow in [idleArrow, activeArrow]) {
      expect(arrow, contains('<polygon points="4,2 4,18 17,10"'));
    }
  });

  test('six operations retain approved titles and SVG endpoint mapping', () {
    const expectedTitles = <BaseCampCommunicationKind, String>{
      BaseCampCommunicationKind.dailyBrief: 'DAILY BRIEF',
      BaseCampCommunicationKind.dailyDebrief: 'DAILY DEBRIEF',
      BaseCampCommunicationKind.weeklyReport: 'WEEKLY REPORT',
      BaseCampCommunicationKind.monthlyReport: 'MONTHLY REPORT',
      BaseCampCommunicationKind.yearlyReport: 'YEARLY REPORT',
      BaseCampCommunicationKind.backup: 'ARK BACKUP',
    };
    for (final entry in expectedTitles.entries) {
      expect(baseCampCommunicationTitle(entry.key), entry.value);
    }
    for (final kind in BaseCampCommunicationKind.values.where(
      (kind) => kind != BaseCampCommunicationKind.backup,
    )) {
      expect(
        baseCampCommunicationEndpoint(kind),
        BaseCampCommunicationEndpoint.documentToComputer,
      );
      expect(
        baseCampCommunicationSourceAsset(kind),
        baseCampCommunicationDocumentAsset,
      );
      expect(
        baseCampCommunicationDestinationIdleAsset(kind),
        baseCampCommunicationComputerIdleAsset,
      );
      expect(
        baseCampCommunicationDestinationCompleteAsset(kind),
        baseCampCommunicationComputerCompleteAsset,
      );
    }
    expect(
      baseCampCommunicationSourceAsset(BaseCampCommunicationKind.backup),
      baseCampCommunicationFolderAsset,
    );
    expect(
      baseCampCommunicationDestinationIdleAsset(
        BaseCampCommunicationKind.backup,
      ),
      baseCampCommunicationServerIdleAsset,
    );
    expect(
      baseCampCommunicationDestinationCompleteAsset(
        BaseCampCommunicationKind.backup,
      ),
      baseCampCommunicationServerCompleteAsset,
    );
  });

  testWidgets('BRIEF uses document to computer and BACKUP folder to server', (
    tester,
  ) async {
    for (final kind in const [
      BaseCampCommunicationKind.dailyBrief,
      BaseCampCommunicationKind.backup,
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: BaseCampCommunicationMotion(
            kind: kind,
            phase: BaseCampCommunicationPhase.running,
          ),
        ),
      );
      await _settleSvg(tester);
      final assets = _renderedSvgAssets(tester);
      expect(assets, contains(baseCampCommunicationSourceAsset(kind)));
      expect(assets, contains(baseCampCommunicationDestinationIdleAsset(kind)));
      expect(
        assets,
        contains(baseCampCommunicationDestinationCompleteAsset(kind)),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'CONNECTING holds idle arrows then transfer advances every 200ms',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BaseCampCommunicationMotion(
            kind: BaseCampCommunicationKind.dailyBrief,
            phase: BaseCampCommunicationPhase.running,
          ),
        ),
      );
      await _settleSvg(tester);

      expect(_frame(0), findsOneWidget);
      expect(find.text('CONNECTING...'), findsOneWidget);
      for (var index = 0; index < 3; index++) {
        expect(_switchOpacity(tester, 'arrow-$index', active: true), 0);
      }
      await tester.pump(
        baseCampCommunicationConnectingDuration -
            const Duration(milliseconds: 1),
      );
      expect(find.text('CONNECTING...'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('RECEIVING...'), findsOneWidget);
      expect(_frame(0), findsOneWidget);

      for (var frame = 1; frame <= 3; frame++) {
        await tester.pump(baseCampCommunicationFrameDuration);
        expect(_frame(frame), findsOneWidget);
        for (var index = 0; index < 3; index++) {
          expect(
            _switchOpacity(tester, 'arrow-$index', active: true),
            index < frame ? 1 : 0,
          );
        }
      }
      await tester.pump(baseCampCommunicationFrameDuration);
      expect(_frame(0), findsOneWidget);
    },
  );

  testWidgets('success swaps idle SVGs and lights all approved arrows', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BaseCampCommunicationMotion(
          kind: BaseCampCommunicationKind.backup,
          phase: BaseCampCommunicationPhase.success,
        ),
      ),
    );
    await _settleSvg(tester);

    expect(_frame(4), findsOneWidget);
    expect(find.text('COMPLETE'), findsOneWidget);
    expect(_switchOpacity(tester, 'destination', active: false), 0);
    expect(_switchOpacity(tester, 'destination', active: true), 1);
    expect(_switchOpacity(tester, 'status-strip', active: false), 0);
    expect(_switchOpacity(tester, 'status-strip', active: true), 1);
    for (var index = 0; index < 3; index++) {
      expect(_switchOpacity(tester, 'arrow-$index', active: true), 1);
    }
  });

  testWidgets('successful task completes before the fixed 2.5 second motion', (
    tester,
  ) async {
    expect(
      baseCampCommunicationConnectingDuration +
          baseCampCommunicationTransferDuration +
          baseCampCommunicationCompletionHold,
      baseCampCommunicationMinimumDisplay,
    );
    final task = Completer<String>();
    String? result;
    await tester.pumpWidget(
      _runnerHost(
        onStart: (context) async {
          result = await BaseCampCommunicationOverlay.run(
            context,
            kind: BaseCampCommunicationKind.dailyDebrief,
            task: () => task.future,
          );
        },
      ),
    );

    await tester.tap(find.text('START'));
    await tester.pump();
    expect(find.byType(BaseCampCommunicationMotion), findsNothing);
    task.complete('saved');
    await _pumpUntilMotion(tester);
    expect(find.text('CONNECTING...'), findsOneWidget);
    expect(find.text('RECEIVED'), findsNothing);
    expect(result, isNull);

    await tester.pump(
      baseCampCommunicationConnectingDuration +
          baseCampCommunicationTransferDuration,
    );
    expect(find.text('RECEIVED'), findsOneWidget);
    expect(result, isNull);
    await tester.pump(const Duration(milliseconds: 800));
    expect(result, isNull);
    await tester.pump(const Duration(milliseconds: 250));
    expect(result, 'saved');
    expect(find.text('DAILY DEBRIEF'), findsNothing);
  });

  testWidgets('pending operation remains motion-free until actual success', (
    tester,
  ) async {
    final task = Completer<void>();
    await tester.pumpWidget(
      _runnerHost(
        onStart: (context) => BaseCampCommunicationOverlay.run<void>(
          context,
          kind: BaseCampCommunicationKind.backup,
          task: () => task.future,
        ),
      ),
    );

    await tester.tap(find.text('START'));
    await tester.pump(const Duration(milliseconds: 3500));
    expect(find.byType(BaseCampCommunicationMotion), findsNothing);
    expect(find.text('COMPLETE'), findsNothing);

    await tester.runAsync(() async {
      task.complete();
      await Future<void>.delayed(const Duration(milliseconds: 1));
    });
    await _pumpUntilMotion(tester);
    expect(find.text('CONNECTING...'), findsOneWidget);
    await tester.pump(
      baseCampCommunicationConnectingDuration +
          baseCampCommunicationTransferDuration,
    );
    expect(find.text('COMPLETE'), findsOneWidget);
    await tester.pump(baseCampCommunicationCompletionHold);
    expect(find.byType(BaseCampCommunicationMotion), findsNothing);
  });

  testWidgets('failure and rejected result never display success', (
    tester,
  ) async {
    final failedTask = Completer<void>();
    Object? caught;
    await tester.pumpWidget(
      _runnerHost(
        onStart: (context) async {
          try {
            await BaseCampCommunicationOverlay.run<void>(
              context,
              kind: BaseCampCommunicationKind.dailyBrief,
              task: () => failedTask.future,
            );
          } catch (error) {
            caught = error;
          }
        },
      ),
    );
    await tester.tap(find.text('START'));
    failedTask.completeError(StateError('save failed'));
    await tester.pump();
    await tester.pump();
    expect(caught, isA<StateError>());
    expect(find.text('RECEIVED'), findsNothing);
    expect(find.byType(BaseCampCommunicationMotion), findsNothing);

    bool? result;
    await tester.pumpWidget(
      _runnerHost(
        onStart: (context) async {
          result = await BaseCampCommunicationOverlay.run<bool>(
            context,
            kind: BaseCampCommunicationKind.backup,
            task: () async => false,
            isSuccess: (value) => value,
          );
        },
      ),
    );
    await tester.tap(find.text('START'));
    await _pumpUntilResult(tester, () => result != null);
    expect(result, isFalse);
    expect(find.text('COMPLETE'), findsNothing);
    expect(find.byType(BaseCampCommunicationMotion), findsNothing);
  });

  testWidgets('idle and complete SVGs remain mounted without switch gaps', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BaseCampCommunicationMotion(
          kind: BaseCampCommunicationKind.dailyDebrief,
          phase: BaseCampCommunicationPhase.running,
        ),
      ),
    );
    await _settleSvg(tester);
    final assets = _renderedSvgAssets(tester);
    expect(assets, contains(baseCampCommunicationComputerIdleAsset));
    expect(assets, contains(baseCampCommunicationComputerCompleteAsset));
    expect(assets, contains(baseCampCommunicationArrowIdleAsset));
    expect(assets, contains(baseCampCommunicationArrowActiveAsset));
    expect(assets, contains(baseCampCommunicationStatusRunningAsset));
    expect(assets, contains(baseCampCommunicationStatusCompleteAsset));
    await tester.pump(baseCampCommunicationConnectingDuration);
    await tester.pump(baseCampCommunicationFrameDuration);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(320, 480), Size(375, 667), Size(390, 844)]) {
    testWidgets('${size.width.toInt()}px keeps the enlarged panel bounded', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: BaseCampCommunicationMotion(
            kind: BaseCampCommunicationKind.dailyDebrief,
            phase: BaseCampCommunicationPhase.running,
          ),
        ),
      );
      await _settleSvg(tester);

      expect(tester.takeException(), isNull);
      final housing = tester.getRect(
        find.byKey(const ValueKey('base-camp-communication-housing')),
      );
      expect(housing.width, closeTo(size.width * .9, .01));
      expect(housing.width, lessThanOrEqualTo(420));
      expect(
        tester.getSize(
          find.byKey(const ValueKey('base-camp-communication-source')),
        ),
        const Size.square(64),
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('base-camp-communication-arrow-0-idle')),
        ),
        const Size.square(20),
      );
      final strip = tester.getRect(
        find.byKey(
          const ValueKey('base-camp-communication-status-strip-surface'),
        ),
      );
      expect(strip.width, lessThanOrEqualTo(256));
      expect(strip.right, lessThanOrEqualTo(housing.right));

      final grid = tester.widget<IgnorePointer>(
        find.byKey(const ValueKey('base-camp-communication-lcd-grid')),
      );
      expect(grid.ignoring, isTrue);
      final gridPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byKey(const ValueKey('base-camp-communication-lcd-grid')),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(gridPaint.painter, isA<BaseCampLcdGrainPainter>());
      expect(BaseCampLcdGrainPainter.pitch, 4);
      expect(BaseCampLcdGrainPainter.opacity, .08);
      final vent = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byKey(const ValueKey('base-camp-communication-vent')),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(vent.painter, isA<BaseCampCommunicationVentPainter>());
    });
  }
}

Finder _frame(int frame) =>
    find.byKey(ValueKey('base-camp-communication-frame-$frame'));

double _switchOpacity(
  WidgetTester tester,
  String switchKey, {
  required bool active,
}) => tester
    .widget<Opacity>(
      find.byKey(
        ValueKey(
          'base-camp-communication-$switchKey-${active ? 'active' : 'idle'}',
        ),
      ),
    )
    .opacity;

Set<String> _renderedSvgAssets(WidgetTester tester) => tester
    .widgetList<SvgPicture>(find.byType(SvgPicture))
    .map((picture) => picture.bytesLoader)
    .whereType<SvgAssetLoader>()
    .map((loader) => loader.assetName)
    .toSet();

Future<void> _settleSvg(WidgetTester tester) async {
  await tester.runAsync(vg.waitForPendingDecodes);
  await tester.pump();
}

Future<void> _pumpUntilMotion(WidgetTester tester) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    if (find.byType(BaseCampCommunicationMotion).evaluate().isNotEmpty) {
      await _settleSvg(tester);
      return;
    }
  }
  fail('Communication overlay did not appear.');
}

Future<void> _pumpUntilResult(
  WidgetTester tester,
  bool Function() completed,
) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    if (completed()) return;
  }
  fail('Communication operation did not complete.');
}

Widget _runnerHost({
  required FutureOr<void> Function(BuildContext context) onStart,
}) => MaterialApp(
  home: Builder(
    builder: (context) => FilledButton(
      onPressed: () {
        final value = onStart(context);
        if (value is Future<void>) unawaited(value);
      },
      child: const Text('START'),
    ),
  ),
);
