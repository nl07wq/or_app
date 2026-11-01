import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/widgets/operation_sequence_overlay.dart';

void main() {
  testWidgets('overlay blocks once, exposes both motions, and dismisses', (
    tester,
  ) async {
    final task = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () {
              unawaited(
                OperationSequenceOverlay.run<void>(
                  context,
                  operationMode: OperationSequenceMode.brief,
                  task: () => task.future,
                ),
              );
            },
            child: const Text('START'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('START'));
    await tester.pump();
    expect(find.text('PROCESSING'), findsOneWidget);
    expect(find.text('MESSAGE ASSEMBLY'), findsOneWidget);
    expect(find.text('VOXEL WALK-IN'), findsOneWidget);

    await tester.tap(find.text('VOXEL WALK-IN'));
    await tester.pump();
    expect(find.text('PROCESSING'), findsOneWidget);

    task.complete();
    await tester.pump();
    expect(find.text('COMPLETE'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('PROCESSING'), findsNothing);
  });

  testWidgets('failure is visual only and the task error still propagates', (
    tester,
  ) async {
    final failure = Completer<void>();
    Object? caught;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              try {
                await OperationSequenceOverlay.run<void>(
                  context,
                  operationMode: OperationSequenceMode.backup,
                  task: () => failure.future,
                );
              } catch (error) {
                caught = error;
              }
            },
            child: const Text('START'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('START'));
    await tester.pump();
    failure.completeError(StateError('failed'));
    await tester.pump();
    expect(find.text('RETURNING TO RESULT'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(caught, isA<StateError>());
  });
}
