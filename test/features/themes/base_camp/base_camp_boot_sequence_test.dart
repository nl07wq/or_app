import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/core/widgets/boot_sequence.dart';
import 'package:or_app/features/themes/base_camp/widgets/base_camp_boot_sequence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DeviceSettingsController.instance.resetForTesting(
      const DeviceSettings(presentationTheme: AppPresentationTheme.baseCamp),
    );
  });

  tearDown(() {
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
  });

  test('boot phases follow verified initialization state', () {
    expect(
      baseCampBootPhaseFor(const AppInitializationState.initializing()),
      BaseCampBootPhase.powerOn,
    );
    expect(
      baseCampBootPhaseFor(
        const AppInitializationState.initializing(
          currentStage: InitializationStage.migratingFood,
        ),
      ),
      BaseCampBootPhase.systemCheck,
    );
    expect(
      baseCampBootPhaseFor(
        const AppInitializationState.initializing(
          currentStage: InitializationStage.verifyingRepositories,
        ),
      ),
      BaseCampBootPhase.baseCampLink,
    );
    expect(
      baseCampBootPhaseFor(
        const AppInitializationState(
          mode: PersistenceMode.indexedDbReadWrite,
          currentStage: InitializationStage.complete,
        ),
      ),
      BaseCampBootPhase.systemReady,
    );
  });

  test('presentation phases follow the monotonic five-stage timeline', () {
    expect(
      baseCampBootPresentationPhaseFor(
        Duration.zero,
        initializationReady: true,
      ),
      BaseCampBootPhase.powerOn,
    );
    expect(
      baseCampBootPresentationPhaseFor(
        const Duration(milliseconds: 250),
        initializationReady: true,
      ),
      BaseCampBootPhase.initializing,
    );
    expect(
      baseCampBootPresentationPhaseFor(
        const Duration(milliseconds: 650),
        initializationReady: true,
      ),
      BaseCampBootPhase.systemCheck,
    );
    expect(
      baseCampBootPresentationPhaseFor(
        const Duration(milliseconds: 1050),
        initializationReady: true,
      ),
      BaseCampBootPhase.baseCampLink,
    );
    expect(
      baseCampBootPresentationPhaseFor(
        const Duration(milliseconds: 1450),
        initializationReady: true,
      ),
      BaseCampBootPhase.systemReady,
    );
    expect(
      baseCampBootPresentationPhaseFor(
        const Duration(seconds: 3),
        initializationReady: false,
      ),
      BaseCampBootPhase.baseCampLink,
    );
  });

  testWidgets('fast initialization shows every stage and releases at 1750ms', (
    tester,
  ) async {
    final initialization = ValueNotifier<AppInitializationState>(
      const AppInitializationState(
        mode: PersistenceMode.indexedDbReadWrite,
        currentStage: InitializationStage.complete,
      ),
    );
    var released = false;
    final events = <BootSequenceEventType>[];
    await tester.pumpWidget(
      _Harness(
        initialization: initialization,
        onReleased: () => released = true,
        onEvent: (event) => events.add(event.type),
      ),
    );

    expect(_phaseText(tester), 'POWER ON');
    await tester.pump(const Duration(milliseconds: 249));
    expect(_phaseText(tester), 'POWER ON');
    await tester.pump(const Duration(milliseconds: 1));
    expect(_phaseText(tester), 'INITIALIZING');
    await tester.pump(const Duration(milliseconds: 400));
    expect(_phaseText(tester), 'SYSTEM CHECK');
    await tester.pump(const Duration(milliseconds: 400));
    expect(_phaseText(tester), 'BASE CAMP LINK');
    await tester.pump(const Duration(milliseconds: 400));
    expect(_phaseText(tester), 'SYSTEM READY');
    expect(find.text('ALL SYSTEMS READY'), findsOneWidget);
    expect(released, isFalse);
    await tester.pump(const Duration(milliseconds: 299));
    expect(released, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(released, isTrue);
    expect(events, <BootSequenceEventType>[
      BootSequenceEventType.bootStart,
      BootSequenceEventType.systemInitialized,
      BootSequenceEventType.bootComplete,
    ]);
    await tester.pump(const Duration(seconds: 1));
    expect(
      events.where((event) => event == BootSequenceEventType.bootComplete),
      hasLength(1),
    );
    initialization.dispose();
  });

  testWidgets('medium initialization retains the complete presentation', (
    tester,
  ) async {
    final initialization = ValueNotifier<AppInitializationState>(
      const AppInitializationState.initializing(),
    );
    var released = false;
    await tester.pumpWidget(
      _Harness(
        initialization: initialization,
        onReleased: () => released = true,
      ),
    );

    await tester.pump(const Duration(milliseconds: 650));
    expect(_phaseText(tester), 'SYSTEM CHECK');
    await tester.pump(const Duration(milliseconds: 150));
    initialization.value = const AppInitializationState(
      mode: PersistenceMode.indexedDbReadWrite,
      currentStage: InitializationStage.complete,
    );
    await tester.pump();
    expect(_phaseText(tester), 'SYSTEM CHECK');
    await tester.pump(const Duration(milliseconds: 250));
    expect(_phaseText(tester), 'BASE CAMP LINK');
    await tester.pump(const Duration(milliseconds: 400));
    expect(_phaseText(tester), 'SYSTEM READY');
    await tester.pump(const Duration(milliseconds: 300));
    expect(released, isTrue);
    initialization.dispose();
  });

  testWidgets('visual stage does not fabricate subsystem readiness', (
    tester,
  ) async {
    final initialization = ValueNotifier<AppInitializationState>(
      const AppInitializationState.initializing(
        currentStage: InitializationStage.verifyingRepositories,
      ),
    );
    await tester.pumpWidget(
      _Harness(initialization: initialization, onReleased: () {}),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(_phaseText(tester), 'SYSTEM CHECK');
    expect(find.text('READY'), findsNWidgets(2));
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('base-camp-boot-system-state')),
          )
          .data,
      'CHECKING',
    );
    expect(find.text('ALL SYSTEMS READY'), findsNothing);
    initialization.dispose();
  });

  testWidgets('failure delegates to existing recovery presentation', (
    tester,
  ) async {
    final initialization = ValueNotifier<AppInitializationState>(
      const AppInitializationState(
        mode: PersistenceMode.failed,
        currentStage: InitializationStage.checkingMigrations,
        errorCode: 'TEST_FAILURE',
        errorMessage: 'failed safely',
      ),
    );
    var released = false;
    await tester.pumpWidget(
      _Harness(
        initialization: initialization,
        onReleased: () => released = true,
      ),
    );

    expect(find.byKey(const ValueKey('startup-fallback')), findsOneWidget);
    expect(find.byKey(const ValueKey('base-camp-boot')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(released, isFalse);
    initialization.dispose();
  });

  for (final elapsed in <int>[100, 400, 800, 1200, 1550]) {
    testWidgets('failure at ${elapsed}ms immediately exposes recovery', (
      tester,
    ) async {
      final initialization = ValueNotifier<AppInitializationState>(
        const AppInitializationState.initializing(),
      );
      var released = false;
      await tester.pumpWidget(
        _Harness(
          initialization: initialization,
          onReleased: () => released = true,
        ),
      );
      await tester.pump(Duration(milliseconds: elapsed));
      initialization.value = const AppInitializationState(
        mode: PersistenceMode.failed,
        currentStage: InitializationStage.checkingMigrations,
        errorCode: 'TEST_FAILURE',
        errorMessage: 'failed safely',
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('startup-fallback')), findsOneWidget);
      expect(find.byKey(const ValueKey('base-camp-boot')), findsNothing);
      expect(released, isFalse);
      initialization.dispose();
    });
  }

  testWidgets('slow initialization holds LINK then acknowledges READY 300ms', (
    tester,
  ) async {
    final initialization = ValueNotifier<AppInitializationState>(
      const AppInitializationState.initializing(
        currentStage: InitializationStage.migratingFood,
      ),
    );
    var released = false;
    await tester.pumpWidget(
      _Harness(
        initialization: initialization,
        onReleased: () => released = true,
      ),
    );

    await tester.pump(const Duration(seconds: 3));

    expect(_phaseText(tester), 'BASE CAMP LINK');
    expect(find.text('LINKING...'), findsOneWidget);
    expect(find.text('ALL SYSTEMS READY'), findsNothing);
    expect(released, isFalse);

    initialization.value = const AppInitializationState(
      mode: PersistenceMode.indexedDbReadWrite,
      currentStage: InitializationStage.complete,
    );
    await tester.pump();
    expect(_phaseText(tester), 'SYSTEM READY');
    expect(find.text('LINK ESTABLISHED'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 299));
    expect(released, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(released, isTrue);
    initialization.dispose();
  });

  testWidgets('reduced motion releases ready state without visual delay', (
    tester,
  ) async {
    final initialization = ValueNotifier<AppInitializationState>(
      const AppInitializationState(
        mode: PersistenceMode.indexedDbReadWrite,
        currentStage: InitializationStage.complete,
      ),
    );
    var released = false;
    await tester.pumpWidget(
      _Harness(
        initialization: initialization,
        onReleased: () => released = true,
        disableAnimations: true,
      ),
    );

    expect(released, isTrue);
    final housing = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('base-camp-boot-housing')),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(housing.opacity, 1);
    initialization.dispose();
  });

  for (final mode in <PersistenceMode>[
    PersistenceMode.maintenance,
    PersistenceMode.legacyReadOnly,
  ]) {
    testWidgets('${mode.name} preserves the existing immediate handoff', (
      tester,
    ) async {
      final initialization = ValueNotifier<AppInitializationState>(
        AppInitializationState(
          mode: mode,
          currentStage: InitializationStage.complete,
        ),
      );
      var released = false;
      await tester.pumpWidget(
        _Harness(
          initialization: initialization,
          onReleased: () => released = true,
        ),
      );

      expect(released, isTrue);
      initialization.dispose();
    });
  }

  for (final width in <double>[320, 375, 390, 430]) {
    for (final negative in <bool>[false, true]) {
      testWidgets('renders without overflow at ${width.toInt()}dp '
          '${negative ? 'INV' : 'LIGHT'}', (tester) async {
        DeviceSettingsController.instance.resetForTesting(
          DeviceSettings(
            presentationTheme: AppPresentationTheme.baseCamp,
            baseCampLcdNegative: negative,
          ),
        );
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final initialization = ValueNotifier<AppInitializationState>(
          const AppInitializationState.initializing(
            currentStage: InitializationStage.migratingFood,
          ),
        );

        await tester.pumpWidget(
          _Harness(initialization: initialization, onReleased: () {}),
        );

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('base-camp-boot-housing')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('base-camp-terminal-lcd-grid')),
          findsOneWidget,
        );
        initialization.dispose();
      });
    }
  }

  testWidgets('short landscape remains scrollable without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final initialization = ValueNotifier<AppInitializationState>(
      const AppInitializationState.initializing(),
    );

    await tester.pumpWidget(
      _Harness(initialization: initialization, onReleased: () {}),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    initialization.dispose();
  });

  testWidgets('background and resume cannot duplicate or strand release', (
    tester,
  ) async {
    final initialization = ValueNotifier<AppInitializationState>(
      const AppInitializationState(
        mode: PersistenceMode.indexedDbReadWrite,
        currentStage: InitializationStage.complete,
      ),
    );
    var releases = 0;
    await tester.pumpWidget(
      _Harness(initialization: initialization, onReleased: () => releases += 1),
    );
    await tester.pump(const Duration(milliseconds: 700));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(releases, 1);
    initialization.dispose();
  });
}

String? _phaseText(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('base-camp-boot-phase')))
    .data;

class _Harness extends StatelessWidget {
  const _Harness({
    required this.initialization,
    required this.onReleased,
    this.disableAnimations = false,
    this.onEvent,
  });

  final ValueListenable<AppInitializationState> initialization;
  final VoidCallback onReleased;
  final bool disableAnimations;
  final BootSequenceEventListener? onEvent;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: BaseCampBootSequenceGate(
        initialization: initialization,
        fallbackBuilder: (state) => const ColoredBox(
          key: ValueKey('startup-fallback'),
          color: Colors.black,
        ),
        onPresentationReleased: onReleased,
        onEvent: onEvent,
      ),
    ),
  );
}
