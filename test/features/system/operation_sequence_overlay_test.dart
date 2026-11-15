import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/widgets/operation_sequence_overlay.dart';
import 'package:or_app/features/themes/base_camp/base_camp_presentation.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_communication_motion.dart';

void main() {
  testWidgets('fast operation exposes skip and never shows Sandbox controls', (
    tester,
  ) async {
    final task = Completer<void>();
    var returned = false;
    await tester.pumpWidget(
      _host((context) async {
        await OperationSequenceOverlay.run<void>(
          context,
          operationMode: OperationSequenceMode.brief,
          task: () => task.future,
        );
        returned = true;
      }),
    );

    await tester.tap(find.text('START'));
    await tester.pump();
    expect(find.text('PROCESSING'), findsOneWidget);
    expect(find.text('MESSAGE ASSEMBLY'), findsNothing);
    expect(find.text('VOXEL WALK-IN'), findsNothing);
    expect(find.text('TAP TO SKIP'), findsNothing);

    task.complete();
    await tester.pump();
    expect(find.text('TAP TO SKIP'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'TAP TO SKIP'));
    await tester.pump();
    expect(returned, isTrue);
    expect(find.text('PROCESSING'), findsNothing);
  });

  testWidgets('completed motion holds PROCESSING until operation settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OperationSequenceOverlay(
          operationMode: OperationSequenceMode.debrief,
          motion: OperationSequenceMotion.voxelWalkIn,
          operationState: OperationSequenceState.running,
          operationFinished: false,
          motionFinished: true,
        ),
      ),
    );
    expect(find.text('PROCESSING'), findsOneWidget);
    expect(find.text('CLOSE'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: OperationSequenceOverlay(
          operationMode: OperationSequenceMode.debrief,
          motion: OperationSequenceMotion.voxelWalkIn,
          operationState: OperationSequenceState.success,
          operationFinished: true,
          motionFinished: true,
        ),
      ),
    );
    expect(find.text('CLOSE'), findsOneWidget);
  });

  testWidgets('failure is returned only after an explicit skip', (
    tester,
  ) async {
    final failure = Completer<void>();
    Object? caught;
    await tester.pumpWidget(
      _host((context) async {
        try {
          await OperationSequenceOverlay.run<void>(
            context,
            operationMode: OperationSequenceMode.backup,
            task: () => failure.future,
          );
        } catch (error) {
          caught = error;
        }
      }),
    );

    await tester.tap(find.text('START'));
    await tester.pump();
    failure.completeError(StateError('failed'));
    await tester.pump();
    expect(caught, isNull);
    await tester.tap(find.widgetWithText(TextButton, 'TAP TO SKIP'));
    await tester.pump();
    expect(caught, isA<StateError>());
  });

  testWidgets('BASE CAMP brief uses communication motion instead of Voxel', (
    tester,
  ) async {
    final task = Completer<void>();
    var returned = false;
    await tester.pumpWidget(
      _host((context) async {
        await OperationSequenceOverlay.run<void>(
          context,
          operationMode: OperationSequenceMode.brief,
          task: () => task.future,
        );
        returned = true;
      }, baseCamp: true),
    );

    await tester.tap(find.text('START'));
    await tester.pump();
    expect(find.text('DAILY BRIEF'), findsOneWidget);
    expect(find.text('CONNECTING...'), findsOneWidget);
    expect(find.text('PROCESSING'), findsNothing);
    await tester.pump(baseCampCommunicationConnectingDuration);
    expect(find.text('RECEIVING...'), findsOneWidget);

    task.complete();
    await tester.pump(
      baseCampCommunicationTransferFloor -
          baseCampCommunicationConnectingDuration,
    );
    expect(find.text('RECEIVED'), findsOneWidget);
    expect(returned, isFalse);
    await tester.pump(baseCampCommunicationCompletionHold);
    expect(returned, isTrue);
  });

  testWidgets('BASE CAMP debrief selects DAILY DEBRIEF communication copy', (
    tester,
  ) async {
    final task = Completer<void>();
    await tester.pumpWidget(
      _host(
        (context) => OperationSequenceOverlay.run<void>(
          context,
          operationMode: OperationSequenceMode.debrief,
          task: () => task.future,
        ),
        baseCamp: true,
      ),
    );

    await tester.tap(find.text('START'));
    await tester.pump();
    expect(find.text('DAILY DEBRIEF'), findsOneWidget);
    expect(find.text('CONNECTING...'), findsOneWidget);
    expect(find.text('PROCESSING'), findsNothing);
    await tester.pump(baseCampCommunicationConnectingDuration);
    expect(find.text('RECEIVING...'), findsOneWidget);

    task.complete();
    await tester.pump(
      baseCampCommunicationTransferFloor -
          baseCampCommunicationConnectingDuration,
    );
    expect(find.text('RECEIVED'), findsOneWidget);
    await tester.pump(baseCampCommunicationCompletionHold);
  });

  testWidgets('BASE CAMP restore opt-out retains the existing Voxel shell', (
    tester,
  ) async {
    final task = Completer<void>();
    await tester.pumpWidget(
      _host(
        (context) => OperationSequenceOverlay.run<void>(
          context,
          operationMode: OperationSequenceMode.backup,
          task: () => task.future,
          useBaseCampCommunication: false,
        ),
        baseCamp: true,
      ),
    );

    await tester.tap(find.text('START'));
    await tester.pump();
    expect(find.text('PROCESSING'), findsOneWidget);
    expect(find.text('ARK BACKUP'), findsNothing);

    task.complete();
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'TAP TO SKIP'));
    await tester.pump();
  });
}

Widget _host(
  FutureOr<void> Function(BuildContext context) onStart, {
  bool baseCamp = false,
}) => MaterialApp(
  home: Builder(
    builder: (context) {
      final child = Builder(
        builder: (context) => FilledButton(
          onPressed: () {
            final value = onStart(context);
            if (value is Future<void>) unawaited(value);
          },
          child: const Text('START'),
        ),
      );
      return baseCamp
          ? BaseCampScreenEntry(
              screen: BaseCampScreen.commandCenter,
              child: child,
            )
          : child;
    },
  ),
);
