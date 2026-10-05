import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/touch_ripple_audio.dart';
import 'package:or_app/core/widgets/global_touch_ripple.dart';
import 'package:or_app/core/widgets/operation_button.dart';
import 'package:or_app/features/morning/widgets/status_crt_back_button.dart';

void main() {
  test('ripple ring model staggers, expands, fades, and expires', () {
    expect(touchRippleRingProgress(Duration.zero, 0), 0);
    expect(touchRippleRingProgress(Duration.zero, 1), isNull);
    expect(touchRippleRingProgress(const Duration(milliseconds: 70), 1), 0);
    expect(
      touchRippleRingRadius(const Duration(milliseconds: 400), 0),
      greaterThan(touchRippleRingRadius(const Duration(milliseconds: 100), 0)!),
    );
    expect(
      touchRippleRingOpacity(const Duration(milliseconds: 700), 0),
      lessThan(touchRippleRingOpacity(const Duration(milliseconds: 100), 0)!),
    );
    expect(touchRippleRingProgress(touchRippleDuration, 0), isNull);
  });

  test('ripple event retention remains bounded and removes expired events', () {
    final events = List.generate(
      touchRippleMaximumActiveEvents,
      (index) => TouchRippleEvent(
        position: Offset(index.toDouble(), 0),
        startedAt: Duration(milliseconds: index),
      ),
    );
    final retained = boundedTouchRippleEvents(
      events,
      const TouchRippleEvent(
        position: Offset(99, 99),
        startedAt: Duration.zero,
      ),
    );
    expect(retained, hasLength(touchRippleMaximumActiveEvents));
    expect(retained.first.position, const Offset(1, 0));
    expect(retained.last.position, const Offset(99, 99));
    expect(
      touchRippleExpired(
        const TouchRippleEvent(position: Offset.zero, startedAt: Duration.zero),
        touchRippleDuration,
      ),
      isTrue,
    );
  });

  testWidgets('overlay observes pointer down without consuming the tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalTouchRipple(
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(width: 120, height: 80),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    expect(taps, 1);
    expect(
      find.byKey(const ValueKey('global-touch-ripple-overlay')),
      findsOneWidget,
    );
  });

  testWidgets('passive touch resolves to Water Drop exactly once', (
    tester,
  ) async {
    final audio = _RecordingTouchRippleAudio();
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalTouchRipple(
          audio: audio,
          child: const ColoredBox(color: Colors.black),
        ),
      ),
    );

    await tester.tapAt(const Offset(40, 40));
    await tester.pump(const Duration(milliseconds: 31));
    expect(audio.played, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));

    expect(audio.played, [TouchFeedbackSound.water]);
  });

  testWidgets('OperationButton excludes generic feedback before it starts', (
    tester,
  ) async {
    final audio = _RecordingTouchRippleAudio();
    var actions = 0;
    var rippleEvents = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalTouchRipple(
          audio: audio,
          onRippleEventCreated: (_) => rippleEvents++,
          child: Scaffold(
            body: Center(
              child: OperationButton(
                text: 'ACTION',
                onPressed: () => actions++,
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('ACTION')),
    );
    await tester.pump();
    expect(rippleEvents, 0);
    expect(audio.played, isEmpty);
    await gesture.up();
    await tester.pump();

    expect(audio.played, [TouchFeedbackSound.success]);
    await tester.pump(const Duration(milliseconds: 32));

    expect(actions, 1);
    expect(audio.played, [TouchFeedbackSound.success]);
  });

  testWidgets('actionable drag cancellation stays fully silent', (
    tester,
  ) async {
    final audio = _RecordingTouchRippleAudio();
    var actions = 0;
    var rippleEvents = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalTouchRipple(
          audio: audio,
          onRippleEventCreated: (_) => rippleEvents++,
          child: Scaffold(
            body: Center(
              child: OperationButton(
                text: 'DRAG ACTION',
                onPressed: () => actions++,
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('DRAG ACTION')),
    );
    await gesture.moveBy(const Offset(0, 40));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 32));

    expect(actions, 0);
    expect(rippleEvents, 0);
    expect(audio.played, isEmpty);
  });

  testWidgets(
    'shared actionable roles own command, exit, and unavailable taps',
    (tester) async {
      final audio = _RecordingTouchRippleAudio();
      var acceptedActions = 0;
      var rippleEvents = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: GlobalTouchRipple(
            audio: audio,
            onRippleEventCreated: (_) => rippleEvents++,
            child: Row(
              children: [
                Expanded(
                  child: ActionableFeedbackRegion(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => acceptedActions++,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Expanded(
                  child: ActionableFeedbackRegion(
                    role: ActionableFeedbackRole.exit,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => acceptedActions++,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Expanded(
                  child: ActionableFeedbackRegion(
                    result: ActionableFeedbackResult.unavailable,
                    child: const SizedBox.expand(),
                  ),
                ),
                const Expanded(child: ColoredBox(color: Colors.black)),
              ],
            ),
          ),
        ),
      );

      await tester.tapAt(const Offset(100, 300));
    await tester.tapAt(const Offset(300, 300));
    await tester.tapAt(const Offset(500, 300));
    await tester.tapAt(const Offset(700, 300));
      await tester.pump(const Duration(milliseconds: 32));

      expect(acceptedActions, 2);
      expect(rippleEvents, 1);
      expect(audio.played, [
        TouchFeedbackSound.success,
        TouchFeedbackSound.exit,
        TouchFeedbackSound.failure,
        TouchFeedbackSound.water,
      ]);
    },
  );

  testWidgets('silent actionable region excludes generic feedback only', (
    tester,
  ) async {
    final audio = _RecordingTouchRippleAudio();
    var actions = 0;
    var rippleEvents = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalTouchRipple(
          audio: audio,
          onRippleEventCreated: (_) => rippleEvents++,
          child: ActionableFeedbackRegion(
            role: ActionableFeedbackRole.silent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => actions++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(100, 100));
    await tester.pump(const Duration(milliseconds: 32));

    expect(actions, 1);
    expect(rippleEvents, 0);
    expect(audio.played, isEmpty);
  });

  testWidgets('stock controls inherit the shared actionable contract', (
    tester,
  ) async {
    final audio = _RecordingTouchRippleAudio();
    var actions = 0;
    var rippleEvents = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalTouchRipple(
          audio: audio,
          onRippleEventCreated: (_) => rippleEvents++,
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'BACK',
                onPressed: () => actions++,
                icon: const Icon(Icons.arrow_back),
              ).actionableFeedback(),
            ),
            body: Wrap(
              children: [
                OutlinedButton(
                  onPressed: () => actions++,
                  child: const Text('OUTLINED'),
                ).actionableFeedback(),
                TextButton(
                  onPressed: () => actions++,
                  child: const Text('TEXT'),
                ).actionableFeedback(),
                ElevatedButton(
                  onPressed: () => actions++,
                  child: const Text('ELEVATED'),
                ).actionableFeedback(),
                PopupMenuButton<String>(
                  tooltip: 'MENU',
                  onSelected: (_) => actions++,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'item',
                      child: ActionableFeedbackButton(
                        enabled: true,
                        child: Text('MENU ITEM'),
                      ),
                    ),
                  ],
                ).actionableFeedback(),
              ],
            ),
          ),
        ),
      ),
    );

    for (final finder in [
      find.byTooltip('BACK'),
      find.text('OUTLINED'),
      find.text('TEXT'),
      find.text('ELEVATED'),
    ]) {
      await tester.tap(finder);
      await tester.pump();
    }
    await tester.tap(find.byTooltip('MENU'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MENU ITEM'));
    await tester.pumpAndSettle();

    expect(actions, 5);
    expect(rippleEvents, 0);
    expect(audio.played, List.filled(6, TouchFeedbackSound.success));
  });

  testWidgets('failure claim suppresses Water Drop and success', (
    tester,
  ) async {
    final audio = _RecordingTouchRippleAudio();
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalTouchRipple(
          audio: audio,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) =>
                GlobalTouchRipple.claimFailure(event.pointer),
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(80, 80));
    await tester.pump(const Duration(milliseconds: 32));

    expect(audio.played, [TouchFeedbackSound.failure]);
  });

  testWidgets('rapid pointer ownership remains isolated', (tester) async {
    final audio = _RecordingTouchRippleAudio();
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalTouchRipple(
          audio: audio,
          child: Row(
            children: [
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) =>
                      GlobalTouchRipple.claimSuccess(event.pointer),
                  child: const SizedBox.expand(),
                ),
              ),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    );

    final semantic = await tester.startGesture(
      const Offset(100, 200),
      pointer: 1,
    );
    await semantic.up();
    final passive = await tester.startGesture(
      const Offset(700, 200),
      pointer: 2,
    );
    await passive.up();
    await tester.pump(const Duration(milliseconds: 32));

    expect(audio.played, [
      TouchFeedbackSound.success,
      TouchFeedbackSound.water,
    ]);
  });

  testWidgets('disabled OperationButton does not claim semantic success', (
    tester,
  ) async {
    final audio = _RecordingTouchRippleAudio();
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalTouchRipple(
          audio: audio,
          child: const Scaffold(
            body: Center(
              child: OperationButton(text: 'DISABLED', onPressed: null),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('DISABLED'));
    await tester.pump(const Duration(milliseconds: 32));

    expect(audio.played, [TouchFeedbackSound.water]);
  });

  testWidgets('explicit unavailable OperationButton claims failure once', (
    tester,
  ) async {
    final audio = _RecordingTouchRippleAudio();
    var rippleEvents = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalTouchRipple(
          audio: audio,
          onRippleEventCreated: (_) => rippleEvents++,
          child: const Scaffold(
            body: Center(
              child: OperationButton(
                text: 'UNAVAILABLE',
                onPressed: null,
                reportUnavailableTap: true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('UNAVAILABLE'));
    await tester.pump();
    expect(rippleEvents, 0);
    expect(audio.played, [TouchFeedbackSound.failure]);
    await tester.pump(const Duration(milliseconds: 32));

    expect(audio.played, [TouchFeedbackSound.failure]);
  });

  testWidgets('semantic and passive pointers retain independent ownership', (
    tester,
  ) async {
    final audio = _RecordingTouchRippleAudio();
    var rippleEvents = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GlobalTouchRipple(
          audio: audio,
          onRippleEventCreated: (_) => rippleEvents++,
          child: Row(
            children: [
              Expanded(
                child: OperationButton(text: 'ACTION', onPressed: () {}),
              ),
              const Expanded(child: ColoredBox(color: Colors.black)),
            ],
          ),
        ),
      ),
    );

    await tester.tapAt(tester.getCenter(find.text('ACTION')));
    await tester.tapAt(const Offset(700, 300));
    await tester.pump(const Duration(milliseconds: 32));

    expect(rippleEvents, 1);
    expect(audio.played, [
      TouchFeedbackSound.success,
      TouchFeedbackSound.water,
    ]);
  });

  testWidgets('STATUS back control claims exit feedback', (tester) async {
    final audio = _RecordingTouchRippleAudio();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            GlobalTouchRipple(audio: audio, child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(leading: const StatusCrtBackButton()),
                  ),
                ),
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('status-crt-back')));
    await tester.pump(const Duration(milliseconds: 32));

    expect(audio.played.last, TouchFeedbackSound.exit);
  });

  testWidgets('Reduced Motion suppresses animation but preserves audio', (
    tester,
  ) async {
    final audio = _RecordingTouchRippleAudio();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: GlobalTouchRipple(
            audio: audio,
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(40, 40));
    await tester.pump(const Duration(milliseconds: 32));

    expect(audio.played, [TouchFeedbackSound.water]);
    final painter = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('global-touch-ripple-overlay')),
    );
    expect(painter.painter, isNotNull);
  });

  test('registers all supplied interaction feedback assets', () {
    expect(
      touchRippleAudioAssetUrl,
      'assets/assets/audio/touch/Water_Drop02-1(Low-Reverb).mp3',
    );
    expect(
      touchRippleSuccessAudioAssetUrl,
      'assets/assets/audio/touch/Cyber03-1.mp3',
    );
    expect(
      touchRippleFailureAudioAssetUrl,
      'assets/assets/audio/touch/cancel-1.mp3',
    );
    expect(
      touchRippleExitAudioAssetUrl,
      'assets/assets/audio/touch/button-09.mp3',
    );
  });
}

class _RecordingTouchRippleAudio implements TouchRippleAudio {
  final played = <TouchFeedbackSound>[];
  var prepared = false;
  var disposed = false;

  @override
  void prepare() => prepared = true;

  @override
  void playFromUserGesture(TouchFeedbackSound sound) => played.add(sound);

  @override
  void dispose() => disposed = true;
}
