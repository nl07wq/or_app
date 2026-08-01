import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/features/command_center/widgets/data_center_page.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';

void main() {
  testWidgets('shows formal Data Center information and existing route', (
    tester,
  ) async {
    await _pump(tester, width: 390, stateLoader: () async => _state());

    expect(find.text('DATA CENTER'), findsOneWidget);
    expect(find.text('SYSTEM STATE'), findsOneWidget);
    expect(find.text('CURRENT OPERATION DATE'), findsOneWidget);
    expect(find.text('2026-08-01'), findsOneWidget);
    expect(find.text('BACKUP SCHEMA'), findsOneWidget);
    expect(find.text('3.0'), findsOneWidget);
    expect(find.text('ENVELOPE VERSION'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('BACKUP SCHEMA 3.0'), findsOneWidget);
    expect(find.text('OPERATION STATE INCLUDED'), findsOneWidget);
    expect(find.text('7 FORMAL SECTIONS'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('OPEN BACKUP & RESTORE'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final action = find.ancestor(
      of: find.text('OPEN BACKUP & RESTORE'),
      matching: find.byType(ElevatedButton),
    );
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('OPEN BACKUP & RESTORE'));
    await tester.pumpAndSettle();
    expect(find.text('BACKUP ROUTE'), findsOneWidget);
  });

  testWidgets('shows non-operable sync and monitoring placeholders', (
    tester,
  ) async {
    await _pump(tester, width: 390, stateLoader: () async => _state());

    for (final label in [
      'TRAINING SYNC',
      'FOOD SYNC',
      'DAILY LOG SYNC',
      'IMPORT HISTORY',
      'CONFLICTS',
      'QUARANTINE',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('COMING LATER'), findsNWidgets(6));
    expect(find.textContaining('OPERATION SYNC'), findsNothing);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('keeps loading, error, and content mutually exclusive', (
    tester,
  ) async {
    final pending = Completer<OperationState>();
    await _pump(tester, width: 390, stateLoader: () => pending.future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('data-center-content')), findsNothing);
    expect(find.text('OPEN BACKUP & RESTORE'), findsNothing);

    pending.completeError(StateError('read failed'));
    await tester.pumpAndSettle();
    expect(find.text('Operation Stateを読み込めませんでした。'), findsOneWidget);
    expect(find.byKey(const ValueKey('data-center-content')), findsNothing);
    expect(find.text('OPEN BACKUP & RESTORE'), findsNothing);
    expect(find.textContaining(DateTime.now().year.toString()), findsNothing);
  });

  for (final width in [320.0, 390.0, 900.0, 1280.0]) {
    testWidgets('is overflow-free at ${width.toInt()}px in light and dark', (
      tester,
    ) async {
      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        await _pump(
          tester,
          width: width,
          theme: theme,
          stateLoader: () async => _state(),
        );
        await tester.drag(
          find.byKey(const ValueKey('data-center-content')),
          const Offset(0, -1200),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required DataCenterStateLoader stateLoader,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(body: DataCenterPage(stateLoader: stateLoader)),
      routes: {
        AppRoutes.backupRestore: (_) =>
            const Scaffold(body: Text('BACKUP ROUTE')),
      },
    ),
  );
  await tester.pump();
}

OperationState _state() {
  final timestamp = DateTime.utc(2026, 8, 1);
  return OperationState(
    operationDate: OperationLocalDate.parse('2026-08-01'),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
