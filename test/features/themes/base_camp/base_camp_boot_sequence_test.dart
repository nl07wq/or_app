import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
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

  testWidgets(
    'shows only verified status and releases ready state next frame',
    (tester) async {
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

      expect(find.text('POWER ON'), findsOneWidget);
      expect(find.text('READY'), findsNothing);
      expect(released, isFalse);

      initialization.value = const AppInitializationState.initializing(
        currentStage: InitializationStage.verifyingRepositories,
      );
      await tester.pump();
      expect(find.text('BASE CAMP LINK'), findsNWidgets(2));
      expect(find.text('READY'), findsNWidgets(2));
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('base-camp-boot-system-state')),
            )
            .data,
        'CHECKING',
      );
      expect(released, isFalse);

      initialization.value = const AppInitializationState(
        mode: PersistenceMode.indexedDbReadWrite,
        currentStage: InitializationStage.complete,
      );
      await tester.pump();
      expect(find.text('SYSTEM READY'), findsNWidgets(2));
      expect(find.text('READY'), findsNWidgets(3));
      expect(released, isTrue);
      initialization.dispose();
    },
  );

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
}

class _Harness extends StatelessWidget {
  const _Harness({required this.initialization, required this.onReleased});

  final ValueListenable<AppInitializationState> initialization;
  final VoidCallback onReleased;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: BaseCampBootSequenceGate(
      initialization: initialization,
      fallbackBuilder: (state) => const ColoredBox(
        key: ValueKey('startup-fallback'),
        color: Colors.black,
      ),
      onPresentationReleased: onReleased,
    ),
  );
}
