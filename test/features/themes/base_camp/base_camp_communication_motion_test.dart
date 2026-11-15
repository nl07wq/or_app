import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/themes/base_camp/base_camp_dashboard_page.dart'
    show BaseCampLcdGrainPainter;
import 'package:or_app/features/themes/base_camp/widgets/base_camp_communication_motion.dart';

void main() {
  test('communication copy is fixed for every operation kind', () {
    expect(
      baseCampCommunicationTitle(BaseCampCommunicationKind.dailyBrief),
      'DAILY BRIEF',
    );
    expect(
      baseCampCommunicationTitle(BaseCampCommunicationKind.dailyDebrief),
      'DAILY DEBRIEF',
    );
    expect(
      baseCampCommunicationTitle(BaseCampCommunicationKind.weeklyReport),
      'WEEKLY REPORT',
    );
    expect(
      baseCampCommunicationTitle(BaseCampCommunicationKind.monthlyReport),
      'MONTHLY REPORT',
    );
    expect(
      baseCampCommunicationTitle(BaseCampCommunicationKind.yearlyReport),
      'YEARLY REPORT',
    );
    expect(
      baseCampCommunicationTitle(BaseCampCommunicationKind.backup),
      'ARK BACKUP',
    );
    expect(
      baseCampCommunicationStatus(
        BaseCampCommunicationKind.dailyBrief,
        BaseCampCommunicationPhase.running,
      ),
      'RECEIVING...',
    );
    expect(
      baseCampCommunicationStatus(
        BaseCampCommunicationKind.dailyDebrief,
        BaseCampCommunicationPhase.success,
      ),
      'RECEIVED',
    );
    expect(
      baseCampCommunicationStatus(
        BaseCampCommunicationKind.backup,
        BaseCampCommunicationPhase.running,
      ),
      'ARCHIVING...',
    );
    expect(
      baseCampCommunicationStatus(
        BaseCampCommunicationKind.backup,
        BaseCampCommunicationPhase.success,
      ),
      'COMPLETE',
    );
    for (final kind in BaseCampCommunicationKind.values.where(
      (kind) => kind != BaseCampCommunicationKind.backup,
    )) {
      expect(
        baseCampCommunicationEndpoint(kind),
        BaseCampCommunicationEndpoint.documentToComputer,
        reason: kind.name,
      );
    }
    expect(
      baseCampCommunicationEndpoint(BaseCampCommunicationKind.backup),
      BaseCampCommunicationEndpoint.folderToServer,
    );
  });

  testWidgets('running transfer advances F0-F3 every 200ms and loops', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BaseCampCommunicationMotion(
          kind: BaseCampCommunicationKind.dailyBrief,
          phase: BaseCampCommunicationPhase.running,
        ),
      ),
    );

    expect(_frame(0), findsOneWidget);
    for (var frame = 1; frame <= 3; frame++) {
      await tester.pump(baseCampCommunicationFrameDuration);
      expect(_frame(frame), findsOneWidget);
    }
    await tester.pump(baseCampCommunicationFrameDuration);
    expect(_frame(0), findsOneWidget);
    expect(find.text('RECEIVING...'), findsOneWidget);
    expect(find.text('RECEIVED'), findsNothing);
  });

  testWidgets('success alone selects F4 and the destination glow', (
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

    expect(_frame(4), findsOneWidget);
    expect(find.text('COMPLETE'), findsOneWidget);
    final paint = tester.widget<CustomPaint>(_frame(4));
    final painter = paint.painter! as BaseCampCommunicationPainter;
    expect(painter.kind, BaseCampCommunicationKind.backup);
    expect(painter.frame, 4);
  });

  testWidgets('fast success enters F4 immediately and holds it for 400ms', (
    tester,
  ) async {
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
    task.complete('saved');
    await tester.pump();
    expect(result, isNull);
    expect(_frame(4), findsOneWidget);
    expect(find.text('RECEIVED'), findsOneWidget);
    expect(result, isNull);

    await tester.pump(const Duration(milliseconds: 399));
    expect(find.text('RECEIVED'), findsOneWidget);
    expect(result, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(result, 'saved');
    expect(find.text('DAILY DEBRIEF'), findsNothing);
  });

  testWidgets('long operation keeps looping without success copy', (
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.text('ARCHIVING...'), findsOneWidget);
    expect(find.text('COMPLETE'), findsNothing);
    expect(find.byType(BaseCampCommunicationMotion), findsOneWidget);

    task.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('COMPLETE'), findsOneWidget);
    await tester.pump(baseCampCommunicationCompletionHold);
  });

  testWidgets('failure never displays success and returns to existing caller', (
    tester,
  ) async {
    final task = Completer<void>();
    Object? caught;
    await tester.pumpWidget(
      _runnerHost(
        onStart: (context) async {
          try {
            await BaseCampCommunicationOverlay.run<void>(
              context,
              kind: BaseCampCommunicationKind.dailyBrief,
              task: () => task.future,
            );
          } catch (error) {
            caught = error;
          }
        },
      ),
    );

    await tester.tap(find.text('START'));
    await tester.pump();
    task.completeError(StateError('save failed'));
    await tester.pump();
    expect(caught, isA<StateError>());
    expect(find.text('RECEIVED'), findsNothing);
    expect(find.text('DAILY BRIEF'), findsNothing);
  });

  testWidgets('false success predicate never displays completion', (
    tester,
  ) async {
    final task = Completer<bool>();
    bool? result;
    await tester.pumpWidget(
      _runnerHost(
        onStart: (context) async {
          result = await BaseCampCommunicationOverlay.run<bool>(
            context,
            kind: BaseCampCommunicationKind.backup,
            task: () => task.future,
            isSuccess: (value) => value,
          );
        },
      ),
    );

    await tester.tap(find.text('START'));
    await tester.pump();
    task.complete(false);
    await tester.pump();
    expect(result, isFalse);
    expect(find.text('COMPLETE'), findsNothing);
    expect(find.text('ARK BACKUP'), findsNothing);
  });

  for (final size in const [Size(320, 480), Size(375, 667), Size(390, 844)]) {
    testWidgets('${size.width.toInt()}px fits without overflow', (
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

      expect(tester.takeException(), isNull);
      final motionRect = tester.getRect(
        find.byType(BaseCampCommunicationMotion),
      );
      final titleRect = tester.getRect(find.text('DAILY DEBRIEF'));
      final statusRect = tester.getRect(find.text('RECEIVING...'));
      expect(titleRect.left, greaterThanOrEqualTo(motionRect.left));
      expect(titleRect.right, lessThanOrEqualTo(motionRect.right));
      expect(statusRect.left, greaterThanOrEqualTo(motionRect.left));
      expect(statusRect.right, lessThanOrEqualTo(motionRect.right));

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
