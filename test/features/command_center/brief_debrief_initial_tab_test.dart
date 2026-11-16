import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/command_center/widgets/brief_debrief_page.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  tearDown(AppRepositoryRegistry.resetForTesting);

  for (final briefExists in [false, true]) {
    for (final debriefExists in [false, true]) {
      test('initial tab matrix brief=$briefExists debrief=$debriefExists', () {
        final tab = briefDebriefInitialTabForState(
          BriefDebriefFormalState(
            operationDate: '2026-11-16',
            briefExists: briefExists,
            debriefExists: debriefExists,
          ),
        );
        expect(
          tab,
          briefExists
              ? BriefDebriefTab.dailyDebrief
              : BriefDebriefTab.dailyBrief,
        );
      });
    }
  }

  test('formal loader uses the current operation date repositories', () async {
    await _installContainer('2026-11-16');

    final state = await loadBriefDebriefFormalState();

    expect(state.operationDate, '2026-11-16');
    expect(state.briefExists, isFalse);
    expect(state.debriefExists, isFalse);
  });

  testWidgets('waits for formal state before presenting either tab', (
    tester,
  ) async {
    await _installContainer('2026-11-16');
    final completer = Completer<BriefDebriefFormalState>();
    await _pumpPage(tester, () => completer.future);

    expect(
      find.byKey(const ValueKey('brief-debrief-initial-tab-loading')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('brief-debrief-tab-bar')), findsNothing);

    completer.complete(
      const BriefDebriefFormalState(
        operationDate: '2026-11-16',
        briefExists: true,
        debriefExists: false,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(_activeTab(tester), BriefDebriefTab.dailyDebrief.index);
  });

  testWidgets('manual selection survives unrelated rebuilds for this visit', (
    tester,
  ) async {
    await _installContainer('2026-11-16');
    final rebuild = ValueNotifier<int>(0);
    addTearDown(rebuild.dispose);
    var loadCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: rebuild,
          builder: (_, _, _) => Scaffold(
            body: BriefDebriefPage(
              key: const ValueKey('brief-debrief-visit'),
              formalStateLoader: () async {
                loadCount++;
                return const BriefDebriefFormalState(
                  operationDate: '2026-11-16',
                  briefExists: false,
                  debriefExists: false,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(_activeTab(tester), BriefDebriefTab.dailyBrief.index);

    await tester.tap(find.text('DAILY DEBRIEF').first);
    await tester.pump(const Duration(milliseconds: 250));
    expect(_activeTab(tester), BriefDebriefTab.dailyDebrief.index);

    rebuild.value++;
    await tester.pump();
    expect(_activeTab(tester), BriefDebriefTab.dailyDebrief.index);
    expect(loadCount, 1);
  });

  testWidgets('new entry reevaluates formal state after record creation', (
    tester,
  ) async {
    await _installContainer('2026-11-16');
    var briefExists = false;
    var loadCount = 0;

    BriefDebriefPage page(String key) => BriefDebriefPage(
      key: ValueKey(key),
      formalStateLoader: () async {
        loadCount++;
        return BriefDebriefFormalState(
          operationDate: '2026-11-16',
          briefExists: briefExists,
          debriefExists: false,
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: page('first-visit'))),
    );
    await tester.pump();
    await tester.pump();
    expect(_activeTab(tester), BriefDebriefTab.dailyBrief.index);

    briefExists = true;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: page('second-visit'))),
    );
    await tester.pump();
    await tester.pump();
    expect(_activeTab(tester), BriefDebriefTab.dailyDebrief.index);
    expect(loadCount, 2);
  });

  testWidgets('date rollover is evaluated on the next screen entry', (
    tester,
  ) async {
    await _installContainer('2026-11-16');
    var operationDate = '2026-11-16';
    var briefExists = true;

    BriefDebriefPage page(String key) => BriefDebriefPage(
      key: ValueKey(key),
      formalStateLoader: () async => BriefDebriefFormalState(
        operationDate: operationDate,
        briefExists: briefExists,
        debriefExists: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: page('date-one'))),
    );
    await tester.pump();
    await tester.pump();
    expect(_activeTab(tester), BriefDebriefTab.dailyDebrief.index);

    operationDate = '2026-11-17';
    briefExists = false;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: page('date-two'))),
    );
    await tester.pump();
    await tester.pump();
    expect(_activeTab(tester), BriefDebriefTab.dailyBrief.index);
  });

  testWidgets('unknown formal state falls back safely to DAILY BRIEF', (
    tester,
  ) async {
    await _installContainer('2026-11-16');
    await _pumpPage(tester, () async => throw StateError('unavailable'));
    await tester.pump();

    expect(_activeTab(tester), BriefDebriefTab.dailyBrief.index);
  });
}

Future<void> _installContainer(String localDate) async {
  final container = AppRepositoryContainer.indexedDb(FakeIndexedDbDatabase());
  await container.operationState.createInitial(
    OperationLocalDate.parse(localDate),
  );
  AppRepositoryRegistry.install(container);
}

Future<void> _pumpPage(
  WidgetTester tester,
  BriefDebriefFormalStateLoader loader,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: BriefDebriefPage(formalStateLoader: loader)),
    ),
  );
  await tester.pump();
}

int _activeTab(WidgetTester tester) => DefaultTabController.of(
  tester.element(find.byKey(const ValueKey('brief-debrief-tab-bar'))),
).index;
