import 'dart:math' as math;

import 'package:flutter/material.dart';

/// These prototypes are deliberately sandbox-only: they do not own data,
/// storage, sound, or transport behavior.
enum BootSendSequenceConcept {
  assemblyMatrix,
  voxelIntegration,
  polyhedralFold,
  messageAssembly,
}

enum BootSendSequencePhase { initializing, buildingData, integrating, complete }

/// Sandbox-only operation selector.  It deliberately has no relationship to
/// the BRIEF / DEBRIEF / BACKUP demonstration label.
enum TransferOperation { save, send }

enum _OperationMode { brief, debrief, backup }

/// Appearance-only choice for the Pixel Builder character. Both variants use
/// the identical construction timeline and data hand-off.
enum SandboxRobotAppearance { original, ark }

/// The final tenth-cell beat is intentionally independent from the robot skin.
enum SandboxPixelBuilderFinale { fall, walkIn }

/// The deliberately readable last-cell beat. It is exposed for focused
/// sandbox verification only; it has no production-operation meaning.
enum SandboxPixelBuilderFinalAct { looking, walking, wobbling, falling, cell }

const _cycle = Duration(milliseconds: 6000);
// Pixel Builder deliberately has a relaxed, readable cadence. The first nine
// cells use a conventional work cycle; the tenth owns a short final-act beat.
const _pixelBuilderInitialMs = 300.0;
const _pixelBuilderWorkScale = 1.5;
const _pixelBuilderCycleMs = 430.0 / _pixelBuilderWorkScale;
const _pixelBuilderHesitationMs = 650.0 / _pixelBuilderWorkScale;
const _pixelBuilderHesitationStartMs =
    _pixelBuilderInitialMs + _pixelBuilderCycleMs * 6;
const _pixelBuilderHesitationEndMs =
    _pixelBuilderHesitationStartMs + _pixelBuilderHesitationMs;
const _pixelBuilderFallFinalActMs = 1050.0;
const _pixelBuilderWalkInFinalActMs = 1350.0;
const _pixelBuilderFinalActStartMs =
    _pixelBuilderInitialMs +
    _pixelBuilderCycleMs * 9 +
    _pixelBuilderHesitationMs;
const _messageAssemblyCycle = Duration(milliseconds: 6500);
const _completionTimeline = Duration(hours: 1);
const _completionTimelineSeconds = 3600.0;

double sandboxPixelBuilderFinalActDurationMs(
  SandboxPixelBuilderFinale finale,
) => finale == SandboxPixelBuilderFinale.walkIn
    ? _pixelBuilderWalkInFinalActMs
    : _pixelBuilderFallFinalActMs;

double sandboxPixelBuilderLoadingEndMs(SandboxPixelBuilderFinale finale) =>
    _pixelBuilderFinalActStartMs +
    sandboxPixelBuilderFinalActDurationMs(finale);

double sandboxPixelVoxelFragmentsEndMs(SandboxPixelBuilderFinale finale) =>
    sandboxPixelBuilderLoadingEndMs(finale) + 750.0;

double sandboxPixelVoxelConstructionEndMs(SandboxPixelBuilderFinale finale) =>
    sandboxPixelVoxelFragmentsEndMs(finale) + 6000.0;

Duration sandboxPixelVoxelCycle(SandboxPixelBuilderFinale finale) =>
    Duration(milliseconds: sandboxPixelVoxelConstructionEndMs(finale).ceil());

/// One authoritative completion predicate for the fractional Pixel Builder
/// timeline. The controller duration is rounded upward, so its last frame is
/// always a completed voxel frame instead of falling just short of it.
bool sandboxPixelVoxelConstructionComplete(
  double elapsedMs,
  SandboxPixelBuilderFinale finale,
) => elapsedMs + .0001 >= sandboxPixelVoxelConstructionEndMs(finale);

class BootSendSequenceSandbox extends StatefulWidget {
  const BootSendSequenceSandbox({super.key});

  @override
  State<BootSendSequenceSandbox> createState() =>
      _BootSendSequenceSandboxState();
}

class _BootSendSequenceSandboxState extends State<BootSendSequenceSandbox>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _completionController;
  var _concept = BootSendSequenceConcept.assemblyMatrix;
  var _mode = _OperationMode.brief;
  var _operation = TransferOperation.save;
  var _robotAppearance = SandboxRobotAppearance.original;
  var _pixelBuilderFinale = SandboxPixelBuilderFinale.fall;
  var _completionStarted = false;

  @override
  void initState() {
    super.initState();
    _completionController = AnimationController(
      vsync: this,
      duration: _completionTimeline,
    );
    _controller =
        AnimationController(vsync: this, duration: _durationFor(_concept))
          ..addListener(_startCompletionTimelineAtConstructionEnd)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              _startCompletionTimelineAtConstructionEnd();
            }
          })
          ..forward();
  }

  void _startCompletionTimelineAtConstructionEnd() {
    // Voxel needs the exact terminal frame because its construction boundary
    // has a fractional millisecond. The older sandbox scenes deliberately
    // retain their accepted near-terminal completion timing.
    final constructionComplete =
        _concept == BootSendSequenceConcept.voxelIntegration
        ? _controller.value >= 1
        : _controller.value >= .999;
    if (mounted && constructionComplete && !_completionStarted) {
      _completionStarted = true;
      _completionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _completionController.dispose();
    super.dispose();
  }

  void _replay() {
    _completionStarted = false;
    _completionController
      ..stop()
      ..value = 0;
    _controller.forward(from: 0);
  }

  Duration _durationFor(BootSendSequenceConcept concept) =>
      concept == BootSendSequenceConcept.voxelIntegration
      ? sandboxPixelVoxelCycle(_pixelBuilderFinale)
      : concept == BootSendSequenceConcept.messageAssembly
      ? _messageAssemblyCycle
      : _cycle;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion && _controller.isAnimating) _controller.stop();
    return Column(
      key: const ValueKey('boot-send-sequence-sandbox'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'BOOT / SEND SEQUENCE',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SegmentedButton<BootSendSequenceConcept>(
          key: const ValueKey('boot-send-sequence-selector'),
          segments: const [
            ButtonSegment(
              value: BootSendSequenceConcept.assemblyMatrix,
              label: FittedBox(child: Text('ASSEMBLY MATRIX')),
            ),
            ButtonSegment(
              value: BootSendSequenceConcept.voxelIntegration,
              label: FittedBox(child: Text('VOXEL INTEGRATION')),
            ),
            ButtonSegment(
              value: BootSendSequenceConcept.polyhedralFold,
              label: FittedBox(child: Text('POLYHEDRAL FOLD')),
            ),
            ButtonSegment(
              value: BootSendSequenceConcept.messageAssembly,
              label: FittedBox(child: Text('MESSAGE ASSEMBLY')),
            ),
          ],
          selected: {_concept},
          onSelectionChanged: (value) {
            setState(() {
              _concept = value.first;
              _controller.duration = _durationFor(_concept);
            });
            _replay();
          },
        ),
        const SizedBox(height: 8),
        SegmentedButton<_OperationMode>(
          key: const ValueKey('boot-send-sequence-mode-selector'),
          segments: const [
            ButtonSegment(value: _OperationMode.brief, label: Text('BRIEF')),
            ButtonSegment(
              value: _OperationMode.debrief,
              label: Text('DEBRIEF'),
            ),
            ButtonSegment(value: _OperationMode.backup, label: Text('BACKUP')),
          ],
          selected: {_mode},
          onSelectionChanged: (value) => setState(() => _mode = value.first),
        ),
        if (_concept == BootSendSequenceConcept.voxelIntegration) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('ROBOT:', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<SandboxRobotAppearance>(
                  key: const ValueKey('boot-send-sequence-robot-selector'),
                  segments: const [
                    ButtonSegment(
                      value: SandboxRobotAppearance.original,
                      label: Text('ORIGINAL'),
                    ),
                    ButtonSegment(
                      value: SandboxRobotAppearance.ark,
                      label: Text('ARK'),
                    ),
                  ],
                  selected: {_robotAppearance},
                  onSelectionChanged: (value) {
                    setState(() => _robotAppearance = value.first);
                    _replay();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('FINALE:', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<SandboxPixelBuilderFinale>(
                  key: const ValueKey('boot-send-sequence-finale-selector'),
                  segments: const [
                    ButtonSegment(
                      value: SandboxPixelBuilderFinale.fall,
                      label: Text('FALL'),
                    ),
                    ButtonSegment(
                      value: SandboxPixelBuilderFinale.walkIn,
                      label: Text('WALK-IN'),
                    ),
                  ],
                  selected: {_pixelBuilderFinale},
                  onSelectionChanged: (value) {
                    setState(() {
                      _pixelBuilderFinale = value.first;
                      _controller.duration = _durationFor(_concept);
                    });
                    _replay();
                  },
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        SegmentedButton<TransferOperation>(
          key: const ValueKey('boot-send-sequence-operation-selector'),
          segments: const [
            ButtonSegment(value: TransferOperation.save, label: Text('SAVE')),
            ButtonSegment(value: TransferOperation.send, label: Text('SEND')),
          ],
          selected: {_operation},
          onSelectionChanged: (value) {
            setState(() => _operation = value.first);
            _replay();
          },
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: Listenable.merge([_controller, _completionController]),
          builder: (_, _) => _SendSequenceMonitor(
            concept: _concept,
            mode: _mode,
            operation: _operation,
            robotAppearance: _robotAppearance,
            pixelBuilderFinale: _pixelBuilderFinale,
            progress: reducedMotion ? 1 : _controller.value,
            completionElapsedSeconds: reducedMotion
                ? 0
                : _completionController.value * _completionTimelineSeconds,
            reducedMotion: reducedMotion,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text(_caption(_concept))),
            TextButton.icon(
              key: const ValueKey('boot-send-sequence-replay'),
              onPressed: _replay,
              icon: const Icon(Icons.replay_outlined, size: 18),
              label: const Text('REPLAY'),
            ),
          ],
        ),
      ],
    );
  }
}

String _caption(BootSendSequenceConcept concept) => switch (concept) {
  BootSendSequenceConcept.assemblyMatrix => 'ASSEMBLY MATRIX',
  BootSendSequenceConcept.voxelIntegration => 'VOXEL INTEGRATION',
  BootSendSequenceConcept.polyhedralFold => 'POLYHEDRAL FOLD',
  BootSendSequenceConcept.messageAssembly => 'MESSAGE ASSEMBLY',
};

String _modeTitle(_OperationMode mode) => switch (mode) {
  _OperationMode.brief => 'BRIEF SEQUENCE',
  _OperationMode.debrief => 'DEBRIEF SEQUENCE',
  _OperationMode.backup => 'BACKUP SEQUENCE',
};

String _modeName(_OperationMode mode) => switch (mode) {
  _OperationMode.brief => 'BRIEF',
  _OperationMode.debrief => 'DEBRIEF',
  _OperationMode.backup => 'BACKUP',
};

/// Public, pure helpers make the message particle geometry testable without a
/// running Canvas. The operation selector deliberately does not affect it.
String sandboxMessageAssemblyMessage(String mode) => switch (mode) {
  'BRIEF' => 'BRIEF RECEIVED',
  'DEBRIEF' => 'DEBRIEF RECEIVED',
  'BACKUP' => 'BACKUP COMPLETE',
  _ => 'BRIEF RECEIVED',
};

const _messageGlyphs = <String, List<String>>{
  'A': ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
  'B': ['11110', '10001', '10001', '11110', '10001', '10001', '11110'],
  'C': ['01111', '10000', '10000', '10000', '10000', '10000', '01111'],
  'D': ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
  'E': ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
  'F': ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
  'I': ['11111', '00100', '00100', '00100', '00100', '00100', '11111'],
  'K': ['10001', '10010', '10100', '11000', '10100', '10010', '10001'],
  'L': ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
  'M': ['10001', '11011', '10101', '10101', '10001', '10001', '10001'],
  'O': ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
  'P': ['11110', '10001', '10001', '11110', '10000', '10000', '10000'],
  'R': ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
  'T': ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
  'U': ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
  'V': ['10001', '10001', '10001', '10001', '10001', '01010', '00100'],
};

/// One square is created for every occupied 5x7 glyph pixel. Target spacing
/// is uniform for the full string so DEBRIEF remains inside the chamber.
List<Offset> sandboxMessageAssemblyTargets(String mode) {
  final text = sandboxMessageAssemblyMessage(mode);
  final columns = text.length * 6 - 1;
  const bounds = Rect.fromLTWH(24, 110, 312, 60);
  final step = math.min(bounds.width / columns, bounds.height / 7);
  final width = columns * step;
  final left = bounds.center.dx - width / 2;
  final top = bounds.center.dy - 7 * step / 2;
  final targets = <Offset>[];
  for (var glyphIndex = 0; glyphIndex < text.length; glyphIndex++) {
    final glyph = _messageGlyphs[text[glyphIndex]];
    if (glyph == null) continue;
    for (var row = 0; row < 7; row++) {
      for (var column = 0; column < 5; column++) {
        if (glyph[row][column] == '1') {
          targets.add(
            Offset(
              left + (glyphIndex * 6 + column + .5) * step,
              top + (row + .5) * step,
            ),
          );
        }
      }
    }
  }
  return targets;
}

/// A stable three-dimensional descriptor for the MESSAGE ASSEMBLY material.
/// These cubes are the same objects throughout impact, propagation, and text
/// formation; the renderer never swaps in a separate text or particle set.
class SandboxMessageCube {
  const SandboxMessageCube({
    required this.id,
    required this.start,
    required this.target,
    required this.size,
    required this.spin,
    required this.delay,
  });

  final int id;
  final SandboxVec3 start;
  final SandboxVec3 target;
  final double size;
  final double spin;
  final double delay;
}

final _messageCubeCache = <String, List<SandboxMessageCube>>{};

List<SandboxMessageCube> sandboxMessageCubes(String mode) =>
    _messageCubeCache.putIfAbsent(mode, () {
      final targets = sandboxMessageAssemblyTargets(mode);
      return List<SandboxMessageCube>.unmodifiable([
        for (var index = 0; index < targets.length; index++)
          SandboxMessageCube(
            id: index,
            // The first large cube is deliberately placed at the comet impact
            // position when the close camera is active.
            start: index == 0
                ? const SandboxVec3(-18, -8, 22)
                : SandboxVec3(
                    math.sin(index * 2.39996) * (78 + index % 5 * 16),
                    math.cos(index * 1.713) * (45 + index % 4 * 13),
                    -58 + ((index * 37) % 132).toDouble(),
                  ),
            target: SandboxVec3(
              (targets[index].dx - 180) / .775,
              (140 - targets[index].dy) / .775,
              (index % 3 - 1) * 1.25,
            ),
            size: index < 16
                ? 10 + (index % 4) * 2
                : index < 62
                ? 5 + (index % 3)
                : 2.2 + (index % 3) * .45,
            spin: (index * 1.137).remainder(math.pi * 2),
            delay: (index % 18) * 19.0,
          ),
      ]);
    });

/// Immutable graph data is calculated once per message. It is shared by paint
/// and tests, so replay cannot invent a new network or depend on frame rate.
class SandboxMessageNetworkEdge {
  const SandboxMessageNetworkEdge(this.a, this.b, this.wave);

  final int a;
  final int b;
  final int wave;
}

final _messageNetworkCache = <String, List<SandboxMessageNetworkEdge>>{};
final _messageSelectedNetworkCache =
    <String, List<SandboxMessageNetworkEdge>>{};
final _messageTargetCountCache = <String, int>{};

Offset _messageBlockStart(String mode, int index) {
  final count = _messageTargetCountCache.putIfAbsent(
    mode,
    () => sandboxMessageAssemblyTargets(mode).length,
  );
  const scene = Rect.fromLTWH(24, 105, 312, 69);
  final seed = index * 12.9898 + count * 3.17 + 78.233;
  return Offset(
    scene.left + ((math.sin(seed) * 43758.5453).abs() % 1) * scene.width,
    scene.top + ((math.sin(seed * 1.71) * 12345.678).abs() % 1) * scene.height,
  );
}

List<SandboxMessageNetworkEdge> sandboxMessageNetworkEdges(String mode) =>
    _messageNetworkCache.putIfAbsent(mode, () {
      final starts = List<Offset>.generate(
        sandboxMessageAssemblyTargets(mode).length,
        (index) => _messageBlockStart(mode, index),
      );
      final degree = List<int>.filled(starts.length, 0);
      final pairs = <(int, int)>[];
      final seen = <String>{};
      for (var index = 0; index < starts.length; index++) {
        final candidates = List<int>.generate(starts.length, (value) => value)
          ..remove(index)
          ..sort(
            (a, b) => (starts[a] - starts[index]).distanceSquared.compareTo(
              (starts[b] - starts[index]).distanceSquared,
            ),
          );
        for (final neighbor in candidates.take(3)) {
          final key = index < neighbor
              ? '$index:$neighbor'
              : '$neighbor:$index';
          if (degree[index] >= 3 || degree[neighbor] >= 4 || !seen.add(key)) {
            continue;
          }
          if ((starts[index] - starts[neighbor]).distance > 62) continue;
          pairs.add((index, neighbor));
          degree[index]++;
          degree[neighbor]++;
          if (degree[index] >= 2) break;
        }
      }
      final adjacency = List<List<int>>.generate(starts.length, (_) => []);
      for (var edgeIndex = 0; edgeIndex < pairs.length; edgeIndex++) {
        adjacency[pairs[edgeIndex].$1].add(edgeIndex);
        adjacency[pairs[edgeIndex].$2].add(edgeIndex);
      }
      final nodeWave = List<int>.filled(starts.length, -1)..[0] = 0;
      final queue = <int>[0];
      while (queue.isNotEmpty) {
        final node = queue.removeAt(0);
        for (final edgeIndex in adjacency[node]) {
          final edge = pairs[edgeIndex];
          final next = edge.$1 == node ? edge.$2 : edge.$1;
          if (nodeWave[next] == -1) {
            nodeWave[next] = nodeWave[node] + 1;
            queue.add(next);
          }
        }
      }
      return List<SandboxMessageNetworkEdge>.unmodifiable([
        for (final pair in pairs)
          SandboxMessageNetworkEdge(
            pair.$1,
            pair.$2,
            math.max(
              0,
              math.min(
                2,
                nodeWave[pair.$1] == -1
                    ? (pair.$1 + pair.$2) % 3
                    : math.min(nodeWave[pair.$1], nodeWave[pair.$2]),
              ),
            ),
          ),
      ]);
    });

/// A deliberately sparse, impact-reachable subset. It is selected once from
/// the full deterministic topology so high-intensity beams read as causal
/// energy transfers instead of a permanent web over the cuboids.
List<SandboxMessageNetworkEdge> sandboxMessageSelectedNetworkEdges(
  String mode,
) => _messageSelectedNetworkCache.putIfAbsent(mode, () {
  final ids = <int>[
    ...List<int>.generate(16, (index) => index),
    23,
    31,
    43,
    57,
    71,
    89,
    107,
    131,
  ];
  final selected = <SandboxMessageNetworkEdge>[];
  final degree = List<int>.filled(ids.length, 0);
  final seen = <String>{};
  void add(int a, int b, int wave) {
    if (degree[a] >= 4 || degree[b] >= 4) return;
    final key = a < b ? '$a:$b' : '$b:$a';
    if (!seen.add(key)) return;
    selected.add(SandboxMessageNetworkEdge(ids[a], ids[b], wave));
    degree[a]++;
    degree[b]++;
  }

  // The first 23 edges are a real impact-rooted spanning backbone. Branches
  // are then added only where their endpoints remain visually distinct.
  for (var node = 1; node < ids.length; node++) {
    add((node - 1) ~/ 2, node, node ~/ 8);
  }
  for (var node = 2; node < ids.length - 2; node++) {
    add(node, node + 2, math.max(node ~/ 8, (node + 2) ~/ 8));
  }
  for (var node = 3; node < ids.length - 4; node += 2) {
    add(node, node + 4, math.max(node ~/ 8, (node + 4) ~/ 8));
  }
  return List<SandboxMessageNetworkEdge>.unmodifiable(selected);
});

/// Smooth local-surface reveal used by the one coherent MESSAGE word object.
/// It deliberately describes material coverage, not camera framing.
double sandboxMessageSurfaceReveal(double elapsedMs) {
  if (elapsedMs <= 3200) return .12;
  if (elapsedMs <= 3700) return .12 + (elapsedMs - 3200) / 500 * .13;
  if (elapsedMs <= 4200) return .25 + (elapsedMs - 3700) / 500 * .20;
  if (elapsedMs <= 4700) return .45 + (elapsedMs - 4200) / 500 * .30;
  if (elapsedMs <= 5200) return .75 + (elapsedMs - 4700) / 500 * .25;
  return 1;
}

double sandboxMessageCameraZoom(double elapsedMs) =>
    3.3 + (1 - 3.3) * _smoothStep(3450, 5650, elapsedMs);

/// Canvas has positive Y downward, so this increasing angle is a visible
/// clockwise roll from an oblique local letter surface toward horizontal.
double sandboxMessageScreenRoll(double elapsedMs) =>
    -72 * (1 - _smoothStep(3350, 5560, elapsedMs));

/// A fine luminous material point emitted from one persistent message cube.
/// Its seed and final glyph-stroke sample are immutable, making every replay
/// reproduce the same cube-to-particle transformation.
class SandboxMessageParticle {
  const SandboxMessageParticle({
    required this.sourceId,
    required this.index,
    required this.target,
    required this.delay,
    required this.size,
    required this.depth,
  });

  final int sourceId;
  final int index;
  final SandboxVec3 target;
  final double delay;
  final double size;
  final double depth;
}

class _MessageWordLayout {
  const _MessageWordLayout({
    required this.text,
    required this.width,
    required this.height,
    required this.finalScale,
  });

  final String text;
  final double width;
  final double height;
  final double finalScale;
}

final _messageParticleCache = <String, List<SandboxMessageParticle>>{};

List<SandboxMessageParticle> sandboxMessageParticles(String mode) =>
    _messageParticleCache.putIfAbsent(mode, () {
      final targets = sandboxMessageAssemblyTargets(mode);
      final cubes = sandboxMessageCubes(mode);
      return List<SandboxMessageParticle>.unmodifiable([
        for (final cube in cubes)
          for (var particle = 0; particle < 6; particle++)
            () {
              final targetIndex =
                  (cube.id * 7 + particle * 29 + particle ~/ 2) %
                  targets.length;
              final base = targets[targetIndex];
              final offsetX = ((particle * 17 + cube.id * 3) % 5 - 2) * .46;
              final offsetY = ((particle * 11 + cube.id * 5) % 5 - 2) * .46;
              return SandboxMessageParticle(
                sourceId: cube.id,
                index: particle,
                target: SandboxVec3(
                  (base.dx + offsetX - 180) / .775,
                  (140 - (base.dy + offsetY)) / .775,
                  ((particle + cube.id) % 4 - 1.5) * .72,
                ),
                delay: (cube.id % 17) * 16.0 + particle * 23.0,
                size: .65 + ((cube.id * 5 + particle * 3) % 7) * .17,
                depth: ((cube.id * 19 + particle * 7) % 11) / 10,
              );
            }(),
      ]);
    });

/// The mode and transfer selectors only label this visual sandbox; neither
/// selector invokes an operation outside the monitor prototype.
String _voxelCompletionMessage(
  _OperationMode mode,
  TransferOperation operation,
) => switch ((mode, operation)) {
  (_OperationMode.backup, _) => 'BACKUP COMPLETE',
  (_, TransferOperation.save) => 'SAVE COMPLETE',
  (_OperationMode.brief, TransferOperation.send) => 'BRIEF RECEIVED',
  (_OperationMode.debrief, TransferOperation.send) => 'DEBRIEF RECEIVED',
};

const sandboxPixelFragmentCount = 27;

/// The seventh through tenth work cycles are shifted by the one deliberate
/// recovery pause after the sixth completed segment.
double sandboxPixelBuilderCycleStartMs(int index) {
  assert(index >= 0 && index < 10);
  return _pixelBuilderInitialMs +
      _pixelBuilderCycleMs * index +
      (index >= 6 ? _pixelBuilderHesitationMs : 0);
}

int sandboxPixelBuilderStrikeCount(int segmentIndex) {
  assert(segmentIndex >= 0 && segmentIndex < 10);
  return switch (segmentIndex) {
    2 || 5 || 8 => 3,
    _ => 2,
  };
}

SandboxPixelBuilderFinalAct sandboxPixelBuilderFinalAct(
  int elapsedMs, {
  SandboxPixelBuilderFinale finale = SandboxPixelBuilderFinale.fall,
}) {
  final local = elapsedMs - _pixelBuilderFinalActStartMs;
  if (local < 300) return SandboxPixelBuilderFinalAct.looking;
  if (finale == SandboxPixelBuilderFinale.walkIn) {
    return local < 770
        ? SandboxPixelBuilderFinalAct.walking
        : SandboxPixelBuilderFinalAct.cell;
  }
  if (local < 590) return SandboxPixelBuilderFinalAct.walking;
  if (local < 770) return SandboxPixelBuilderFinalAct.wobbling;
  if (local < 950) return SandboxPixelBuilderFinalAct.falling;
  return SandboxPixelBuilderFinalAct.cell;
}

/// A segment permanently locks at the end of its final work cycle. This makes
/// the visible 100% transition land exactly at 3825ms.
int sandboxPixelBuilderFilledSegments(
  int elapsedMs, {
  SandboxPixelBuilderFinale finale = SandboxPixelBuilderFinale.fall,
}) {
  var filled = 0;
  for (var index = 0; index < 9; index++) {
    if (elapsedMs >=
        sandboxPixelBuilderCycleStartMs(index) + _pixelBuilderCycleMs) {
      filled++;
    }
  }
  // The final module is completed by the falling robot, not another strike.
  if (elapsedMs >= sandboxPixelBuilderLoadingEndMs(finale)) filled++;
  return filled;
}

double _pixelBuilderLocalMs(double elapsedMs, int index) =>
    (elapsedMs - sandboxPixelBuilderCycleStartMs(index))
        .clamp(0, _pixelBuilderCycleMs)
        .toDouble();

Rect sandboxPixelBuilderSegmentRect(int index) {
  assert(index >= 0 && index < 10);
  return Rect.fromLTWH(56 + 22.0 * index, 158, 17, 18);
}

/// Deterministic 10-to-27 mapping: the first seven bar modules split into
/// three fragments, while the final three split into two.
int sandboxPixelFragmentModule(int fragmentIndex) {
  assert(fragmentIndex >= 0 && fragmentIndex < sandboxPixelFragmentCount);
  if (fragmentIndex < 21) return fragmentIndex ~/ 3;
  return 7 + ((fragmentIndex - 21) ~/ 2);
}

Offset sandboxPixelFragmentSource(int fragmentIndex) {
  final module = sandboxPixelFragmentModule(fragmentIndex);
  final rect = sandboxPixelBuilderSegmentRect(module);
  final first = module < 7;
  final localIndex = first ? fragmentIndex % 3 : (fragmentIndex - 21) % 2;
  final pieces = first ? 3 : 2;
  return Offset(
    rect.left + rect.width * ((localIndex + .5) / pieces),
    rect.center.dy,
  );
}

BootSendSequencePhase bootSendSequencePhase(double progress) {
  final value = progress.clamp(0, 1).toDouble();
  if (value < .2) return BootSendSequencePhase.initializing;
  if (value < 7 / 15) return BootSendSequencePhase.buildingData;
  if (value < 23 / 30) return BootSendSequencePhase.integrating;
  return BootSendSequencePhase.complete;
}

String bootSendSequencePhaseLabel(BootSendSequencePhase phase) =>
    switch (phase) {
      BootSendSequencePhase.initializing => 'INITIALIZING',
      BootSendSequencePhase.buildingData => 'BUILDING DATA',
      BootSendSequencePhase.integrating => 'INTEGRATING',
      BootSendSequencePhase.complete => 'COMPLETE',
    };

double _phase(double value, double start, double end) =>
    ((value - start) / (end - start)).clamp(0, 1).toDouble();
bool _isConstructionComplete(double progress) => progress >= .999;
double _ease(double value) =>
    Curves.easeInOutCubic.transform(value.clamp(0, 1));

class _SendSequenceMonitor extends StatelessWidget {
  const _SendSequenceMonitor({
    required this.concept,
    required this.mode,
    required this.operation,
    required this.robotAppearance,
    required this.pixelBuilderFinale,
    required this.progress,
    required this.completionElapsedSeconds,
    required this.reducedMotion,
  });

  final BootSendSequenceConcept concept;
  final _OperationMode mode;
  final TransferOperation operation;
  final SandboxRobotAppearance robotAppearance;
  final SandboxPixelBuilderFinale pixelBuilderFinale;
  final double progress;
  final double completionElapsedSeconds;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 360 / 280,
    child: RepaintBoundary(
      child: CustomPaint(
        key: const ValueKey('boot-send-sequence-monitor'),
        painter: _SendSequencePainter(
          concept: concept,
          mode: mode,
          operation: operation,
          robotAppearance: robotAppearance,
          pixelBuilderFinale: pixelBuilderFinale,
          progress: progress,
          completionElapsedSeconds: completionElapsedSeconds,
          reducedMotion: reducedMotion,
        ),
      ),
    ),
  );
}

class _SendSequencePainter extends CustomPainter {
  const _SendSequencePainter({
    required this.concept,
    required this.mode,
    required this.operation,
    required this.robotAppearance,
    required this.pixelBuilderFinale,
    required this.progress,
    required this.completionElapsedSeconds,
    required this.reducedMotion,
  });

  final BootSendSequenceConcept concept;
  final _OperationMode mode;
  final TransferOperation operation;
  final SandboxRobotAppearance robotAppearance;
  final SandboxPixelBuilderFinale pixelBuilderFinale;
  final double progress;
  final double completionElapsedSeconds;
  final bool reducedMotion;

  bool _monitorConstructionComplete(double progress) =>
      concept == BootSendSequenceConcept.voxelIntegration
      ? progress >= 1
      : _isConstructionComplete(progress);

  static const _screen = Color(0xff030d15);
  static const _cyan = Color(0xff39ddf2);
  static const _ice = Color(0xffd8fbff);
  static const _violet = Color(0xff9588d9);

  Paint _fill(Color color) => Paint()..color = color;
  Paint _line(Color color, [double width = 1]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;
  Paint _glow(Color color, double sigma, [double width = 1]) =>
      _line(color, width)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 360, size.height / 280);
    canvas.save();
    canvas.translate(
      (size.width - 360 * scale) / 2,
      (size.height - 280 * scale) / 2,
    );
    canvas.scale(scale);
    final t = progress.clamp(0, 1).toDouble();
    _housing(canvas);
    _grid(canvas);
    _header(canvas, t);
    final particleField = _monitorConstructionComplete(t)
        ? _completedParticleField(completionElapsedSeconds)
        : null;
    if (particleField != null) {
      _paintParticles(canvas, particleField, reducedMotion: reducedMotion);
    }
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(20, 72, 320, 137));
    switch (concept) {
      case BootSendSequenceConcept.assemblyMatrix:
        _assemblyMatrix(canvas, t, completionElapsedSeconds);
      case BootSendSequenceConcept.voxelIntegration:
        _voxelIntegration(canvas, t, completionElapsedSeconds);
      case BootSendSequenceConcept.polyhedralFold:
        _polyhedralFold(canvas, t, completionElapsedSeconds);
      case BootSendSequenceConcept.messageAssembly:
        _messageAssembly(canvas, t);
    }
    canvas.restore();
    if (particleField != null) {
      _paintParticles(
        canvas,
        particleField,
        frontOnly: true,
        reducedMotion: reducedMotion,
      );
    }
    _footer(canvas, t);
    _bezel(canvas);
    canvas.restore();
  }

  void _housing(Canvas canvas) {
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 4, 352, 272),
      const Radius.circular(13),
    );
    canvas.drawRRect(body, _fill(const Color(0xff101c25)));
    canvas.drawRRect(body, _line(const Color(0xff45697a), 2));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 10, 340, 260),
        const Radius.circular(9),
      ),
      _fill(const Color(0xff061018)),
    );
    canvas.drawRect(const Rect.fromLTWH(19, 21, 322, 238), _fill(_screen));
    canvas.drawRect(
      const Rect.fromLTWH(19, 21, 322, 238),
      _line(const Color(0xff31788a)),
    );
    for (final x in [31.0, 303.0]) {
      for (var row = 0; row < 2; row++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 14 + row * 4, 26, 3),
            const Radius.circular(1),
          ),
          _fill(row == 0 ? const Color(0xff294957) : const Color(0xff172f3b)),
        );
      }
    }
    for (final point in const [
      Offset(13, 13),
      Offset(347, 13),
      Offset(13, 267),
      Offset(347, 267),
    ]) {
      canvas.drawCircle(point, 2, _fill(const Color(0xff5a7a87)));
      canvas.drawCircle(point, .75, _fill(const Color(0xff0b151c)));
    }
    for (final point in const [
      Offset(20, 22),
      Offset(340, 22),
      Offset(20, 258),
      Offset(340, 258),
    ]) {
      final sx = point.dx < 180 ? 1.0 : -1.0;
      final sy = point.dy < 140 ? 1.0 : -1.0;
      final paint = _line(const Color(0xff64bfcf), 1.4);
      canvas.drawLine(point, point + Offset(12 * sx, 0), paint);
      canvas.drawLine(point, point + Offset(0, 12 * sy), paint);
    }
  }

  void _grid(Canvas canvas) {
    final paint = _line(const Color(0xff6ba4b5).withValues(alpha: .045), .6);
    for (var x = 20.0; x < 341; x += 24) {
      canvas.drawLine(Offset(x, 22), Offset(x, 258), paint);
    }
    for (var y = 22.0; y < 259; y += 24) {
      canvas.drawLine(Offset(20, y), Offset(340, y), paint);
    }
  }

  void _header(Canvas canvas, double t) {
    _text(
      canvas,
      'SYSTEM / 01',
      const Offset(30, 35),
      9,
      const Color(0xff7ba9b8),
    );
    _center(canvas, _modeTitle(mode), const Offset(180, 39), 10, _ice);
    _text(canvas, 'SANDBOX', const Offset(279, 35), 8, const Color(0xff6f9bac));
    final color = _monitorConstructionComplete(t)
        ? const Color(0xff8af6e9)
        : const Color(0xff2d8fa7);
    canvas.drawCircle(
      const Offset(327, 39),
      5,
      _glow(color.withValues(alpha: .35), 7, 5),
    );
    canvas.drawCircle(
      const Offset(327, 39),
      5,
      _glow(color.withValues(alpha: .75), 3, 3),
    );
    canvas.drawCircle(const Offset(327, 39), 3, _fill(color));
    canvas.drawLine(
      const Offset(30, 65),
      const Offset(330, 65),
      _line(const Color(0xff386277), .7),
    );
  }

  void _footer(Canvas canvas, double t) {
    final completed = _monitorConstructionComplete(t);
    final state = concept == BootSendSequenceConcept.messageAssembly
        ? completed
              ? sandboxMessageAssemblyMessage(_modeName(mode))
              : 'MESSAGE ASSEMBLY'
        : concept == BootSendSequenceConcept.voxelIntegration
        ? completed
              ? _voxelCompletionMessage(mode, operation)
              : t <
                    sandboxPixelBuilderLoadingEndMs(pixelBuilderFinale) /
                        sandboxPixelVoxelCycle(
                          pixelBuilderFinale,
                        ).inMilliseconds
              ? 'PIXEL BUILD'
              : t <
                    sandboxPixelVoxelFragmentsEndMs(pixelBuilderFinale) /
                        sandboxPixelVoxelCycle(
                          pixelBuilderFinale,
                        ).inMilliseconds
              ? 'FRAGMENTING DATA'
              : 'VOXEL ASSEMBLY'
        : completed
        ? operation == TransferOperation.save
              ? 'STORAGE LOCKED'
              : 'RECEIVER ACK'
        : switch (operation) {
            TransferOperation.save => 'WRITING PACKAGE',
            TransferOperation.send => 'TRANSPORT ACTIVE',
          };
    _text(
      canvas,
      _caption(concept),
      const Offset(30, 219),
      8,
      const Color(0xff71a7b8),
    );
    _text(
      canvas,
      '${(t * 100).round().clamp(0, 100)}%',
      const Offset(30, 231),
      9,
      const Color(0xffa1dbe6),
    );
    _right(
      canvas,
      state,
      const Offset(330, 230),
      8.5,
      completed ? const Color(0xffc6fff7) : const Color(0xff6694a5),
    );
    final active = (t * 20).floor().clamp(0, 20);
    for (var index = 0; index < 20; index++) {
      final color = completed
          ? const Color(0xff8af6e9)
          : index < active
          ? const Color(0xff42daf2)
          : const Color(0xff193443);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(30 + index * 14, 242, 10, 5),
          const Radius.circular(1),
        ),
        _fill(color),
      );
    }
  }

  void _bezel(Canvas canvas) {
    canvas.drawLine(
      const Offset(13, 29),
      const Offset(13, 245),
      _line(const Color(0xff7bc6d5).withValues(alpha: .17), .7),
    );
    canvas.drawLine(
      const Offset(347, 29),
      const Offset(347, 245),
      _line(const Color(0xff02080c)),
    );
  }

  SandboxParticleField _completedParticleField(double elapsedSeconds) {
    final bounds = switch (concept) {
      BootSendSequenceConcept.assemblyMatrix => const Rect.fromLTWH(
        278,
        112,
        52,
        56,
      ),
      BootSendSequenceConcept.voxelIntegration => const Rect.fromLTWH(
        116,
        86,
        130,
        112,
      ),
      BootSendSequenceConcept.polyhedralFold => const Rect.fromLTWH(
        274,
        103,
        60,
        70,
      ),
      BootSendSequenceConcept.messageAssembly => const Rect.fromLTWH(
        24,
        105,
        312,
        69,
      ),
    };
    final contentBounds = const Rect.fromLTWH(25, 72, 310, 137);
    final expanded = Rect.fromLTRB(
      math.max(contentBounds.left, bounds.left - 18),
      math.max(contentBounds.top, bounds.top - 13),
      math.min(contentBounds.right, bounds.right + 18),
      math.min(contentBounds.bottom, bounds.bottom + 13),
    );
    return SandboxParticleField(
      center: expanded.center,
      spawnBounds: expanded,
      palette: const [
        Color(0xff63d8ff),
        Color(0xffb5f3ff),
        Color(0xffa69aff),
        Color(0xffe8fcff),
      ],
      density: sandboxParticleCount(concept),
      motionBias: switch (concept) {
        BootSendSequenceConcept.assemblyMatrix =>
          const SandboxParticleMotionBias(6, 9, 4, 6),
        BootSendSequenceConcept.voxelIntegration =>
          const SandboxParticleMotionBias(8, 14, 6, 10),
        BootSendSequenceConcept.polyhedralFold =>
          const SandboxParticleMotionBias(7, 12, 5, 8),
        BootSendSequenceConcept.messageAssembly =>
          const SandboxParticleMotionBias(6, 9, 4, 6),
      },
      seed: switch (concept) {
        BootSendSequenceConcept.assemblyMatrix => 3101,
        BootSendSequenceConcept.voxelIntegration => 3102,
        BootSendSequenceConcept.polyhedralFold => 3103,
        BootSendSequenceConcept.messageAssembly => 3104,
      },
      elapsedTime: elapsedSeconds,
      depthLayer: SandboxParticleDepthLayer.back,
    );
  }

  void _paintParticles(
    Canvas canvas,
    SandboxParticleField field, {
    bool frontOnly = false,
    required bool reducedMotion,
  }) {
    final layers = frontOnly
        ? const [SandboxParticleDepthLayer.front]
        : const [
            SandboxParticleDepthLayer.back,
            SandboxParticleDepthLayer.side,
          ];
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(20, 72, 320, 137));
    for (final layer in layers) {
      for (final particle in sandboxParticleVisuals(
        field.copyWith(depthLayer: layer),
        reducedMotion: reducedMotion,
      )) {
        final wide = particle.color.withValues(alpha: particle.wideAlpha);
        final near = particle.color.withValues(alpha: particle.nearAlpha);
        canvas.drawCircle(
          particle.position,
          particle.radius * 2.5,
          _fill(wide)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5),
        );
        canvas.drawCircle(
          particle.position,
          particle.radius * 1.55,
          _fill(near)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
        );
        canvas.drawCircle(
          particle.position,
          particle.radius,
          _fill(particle.color.withValues(alpha: particle.coreAlpha)),
        );
      }
    }
    canvas.restore();
  }

  /// A fourth, independent scene. Its typography is made exclusively from
  /// deterministic 3D data cubes rather than a Text fade-in.
  void _messageAssembly(Canvas canvas, double t) {
    final elapsed = t * _messageAssemblyCycle.inMilliseconds;
    final modeName = _modeName(mode);
    final cubes = sandboxMessageCubes(modeName);
    final edges = sandboxMessageSelectedNetworkEdges(modeName);
    final particles = sandboxMessageParticles(modeName);
    const scene = Rect.fromLTWH(14, 72, 332, 128);
    canvas.save();
    canvas.clipRect(scene);
    final transforms = [
      for (final cube in cubes) _messageCubeTransform(cube, elapsed),
    ];
    final projected = [
      for (final transform in transforms) _messageProject(transform, elapsed),
    ];
    final impact = _messageImpactIntensity(elapsed);
    // The graph is an activation aid, not the subject. It stays bright while
    // a pulse is travelling, then leaves only a compact afterglow as the
    // cube material transfers into the flowing particle field.
    final beamFade = 1 - _ease(_phase(elapsed, 2400, 3600));
    final nodeIllumination = List<double>.filled(cubes.length, 0)..[0] = impact;

    // The comet is intentionally the first major event, and targets cube 0.
    if (elapsed >= 350 && elapsed <= 1050) {
      final comet = Offset.lerp(
        const Offset(380, 78),
        projected.first.offset,
        _ease(_phase(elapsed, 350, 850)),
      )!;
      canvas.drawLine(
        Offset(comet.dx + 42, comet.dy - 16),
        comet,
        _glow(const Color(0xff63f4d4).withValues(alpha: .55), 8, 5),
      );
      canvas.drawCircle(comet, 5 + impact * 8, _glow(_ice, 5, 4));
      canvas.drawCircle(comet, 2.8, _fill(const Color(0xfff1ffff)));
    }
    if (impact > 0) {
      final point = projected.first.offset;
      for (var ray = 0; ray < 9; ray++) {
        final angle = ray * math.pi * 2 / 9 + .17;
        final length = 14 + impact * 38;
        canvas.drawLine(
          point,
          point + Offset(math.cos(angle) * length, math.sin(angle) * length),
          _glow(const Color(0xff85ffe1).withValues(alpha: impact * .34), 4, 2),
        );
      }
      canvas.drawCircle(
        point,
        14 + impact * 20,
        _glow(_ice.withValues(alpha: impact * .55), 9, 6),
      );
    }

    // Beams precede faces so nearby cuboids still occlude background links.
    for (var edgeIndex = 0; edgeIndex < edges.length; edgeIndex++) {
      final edge = edges[edgeIndex];
      final pulse = _messageEdgePulse(elapsed, edge, edgeIndex);
      final strength =
          _messageEdgeStrength(elapsed, edge, edgeIndex) * beamFade;
      if (pulse <= 0 || strength < .10) continue;
      nodeIllumination[edge.a] = math.max(
        nodeIllumination[edge.a],
        strength * .72,
      );
      if (pulse > .9) {
        nodeIllumination[edge.b] = math.max(nodeIllumination[edge.b], strength);
      }
      final from = projected[edge.a].offset;
      final to = projected[edge.b].offset;
      final head = Offset.lerp(from, to, pulse)!;
      canvas.drawLine(
        from,
        to,
        _glow(const Color(0xff45eac6).withValues(alpha: strength * .28), 7, 6),
      );
      canvas.drawLine(
        from,
        head,
        _line(_cyan.withValues(alpha: strength * .88), 1.8),
      );
      canvas.drawLine(from, head, _line(_ice.withValues(alpha: strength), .75));
      canvas.drawCircle(
        head,
        3.4,
        _glow(_ice.withValues(alpha: strength), 3.4, 3),
      );
      if (pulse > .94) {
        canvas.drawCircle(
          to,
          4.2,
          _glow(
            const Color(0xff85ffe1).withValues(alpha: strength * .62),
            4,
            3,
          ),
        );
      }
    }

    final faces = <_RenderFace>[];
    for (var index = 0; index < cubes.length; index++) {
      final cube = cubes[index];
      final transform = transforms[index];
      final materialTransfer = _messageMaterialTransfer(elapsed, cube);
      // The intact solid recedes only after its own local stream is visible.
      // It never turns into a one-cube bitmap text pixel.
      final renderSize = cube.size * (1 - materialTransfer * .62);
      final illumination = math.max(
        nodeIllumination[index],
        index == 0 ? impact : 0,
      );
      final base = switch (index % 4) {
        0 => const Color(0xffb5f3ff),
        1 => const Color(0xff7ea8ff),
        _ => const Color(0xff63d8ff),
      }.withValues(alpha: (.72 + illumination * .23) * (1 - materialTransfer));
      final angle =
          (cube.spin + elapsed / 1000 * (.42 + (index % 3) * .12)) *
          (1 - materialTransfer * .72);
      // Spin faces around their own cube center only. Rotating absolute
      // coordinates here would make an already-arrived glyph cube orbit away
      // from its target and visually postpone letter formation.
      SandboxVec3 orientVertex(SandboxVec3 point) =>
          (transform + (point - transform).rotateY(angle).rotateX(angle * .55))
              .rotateY(_messageWorldYaw(elapsed))
              .rotateX(_messageWorldPitch(elapsed));
      SandboxVec3 orientNormal(SandboxVec3 normal) => normal
          .rotateY(angle)
          .rotateX(angle * .55)
          .rotateY(_messageWorldYaw(elapsed))
          .rotateX(_messageWorldPitch(elapsed));
      if (base.a > .02) {
        for (final face in sandboxCubeFaces(transform, renderSize)) {
          faces.add(
            _RenderFace(
              face.vertices.map(orientVertex).toList(),
              orientNormal(face.normal),
              base,
            ),
          );
        }
      }
      if (illumination > .2) {
        canvas.drawCircle(
          projected[index].offset,
          4 + renderSize * .20,
          _glow(base.withValues(alpha: illumination * .25), 4, 3),
        );
      }
    }
    _paint3dFaces(
      canvas,
      _MessageProjection(elapsed),
      faces,
      border: _ice.withValues(alpha: .68),
    );
    _paintMessageParticles(canvas, particles, cubes, transforms, elapsed);
    if (elapsed >= 3000) {
      _paintMessageWordSurface(canvas, modeName, elapsed);
    }
    // Keep a compact foreground specular flash at the actual struck node.
    // The radial bloom above is correctly behind the opaque cube faces; this
    // small overlay keeps the impact legible at native phone scale.
    if (impact > 0) {
      final point = projected.first.offset;
      for (var ray = 0; ray < 6; ray++) {
        final angle = ray * math.pi * 2 / 6 + .31;
        final end =
            point +
            Offset(
              math.cos(angle) * (7 + impact * 18),
              math.sin(angle) * (7 + impact * 18),
            );
        canvas.drawLine(
          point,
          end,
          _line(_ice.withValues(alpha: impact * .58), .8),
        );
      }
      canvas.drawCircle(
        point,
        3 + impact * 7,
        _glow(_ice.withValues(alpha: impact * .82), 6, 4),
      );
      canvas.drawCircle(
        point,
        1.6 + impact * 1.4,
        _fill(const Color(0xfff1ffff).withValues(alpha: impact)),
      );
    }
    if (elapsed >= 5100) {
      final wave = _phase(elapsed, 5100, 5600);
      canvas.drawLine(
        Offset(scene.left + scene.width * wave, scene.top),
        Offset(scene.left + scene.width * wave - 28, scene.bottom),
        _glow(_ice.withValues(alpha: .22 * (1 - wave)), 4, 1.4),
      );
    }
    canvas.restore();
  }

  SandboxVec3 _messageCubeTransform(SandboxMessageCube cube, double elapsed) {
    final drift = SandboxVec3(
      math.sin(elapsed / 430 + cube.spin) * 3,
      math.cos(elapsed / 510 + cube.spin) * 2,
      math.sin(elapsed / 610 + cube.spin) * 3,
    );
    // Common rotation and contraction keep the cloud visibly connected. Each
    // cube then receives a staggered attraction to its permanent glyph slot.
    final rotation = _ease(_phase(elapsed, 2400, 4000));
    final contraction = _ease(_phase(elapsed, 2700, 4400));
    final attraction = _ease(
      _phase(elapsed, 3000 + cube.delay * .25, 4500 + cube.delay * .1),
    );
    final cloud = (cube.start + drift)
        .rotateY(rotation * 85 * math.pi / 180)
        .rotateX(-rotation * 15 * math.pi / 180);
    final contracted = SandboxVec3.lerp(cloud, cloud * .34, contraction);
    return SandboxVec3.lerp(contracted, cube.target, attraction);
  }

  double _messageMaterialTransfer(double elapsed, SandboxMessageCube cube) =>
      _ease(_phase(elapsed, 2400 + cube.delay * .28, 4100 + cube.delay * .22));

  double _messageParticleFlow(
    double elapsed,
    SandboxMessageParticle particle,
  ) => _ease(
    _phase(elapsed, 2650 + particle.delay, 4650 + particle.delay * .28),
  );

  Offset _messageBezier(
    Offset start,
    Offset firstControl,
    Offset secondControl,
    Offset end,
    double progress,
  ) {
    final inverse = 1 - progress;
    return start * (inverse * inverse * inverse) +
        firstControl * (3 * inverse * inverse * progress) +
        secondControl * (3 * inverse * progress * progress) +
        end * (progress * progress * progress);
  }

  void _paintMessageParticles(
    Canvas canvas,
    List<SandboxMessageParticle> particles,
    List<SandboxMessageCube> cubes,
    List<SandboxVec3> transforms,
    double elapsed,
  ) {
    // Immutable descriptors keep this material field deterministic without
    // reconstructing any scene topology in the paint loop.
    for (final particle in particles) {
      final cube = cubes[particle.sourceId];
      final transfer = _messageMaterialTransfer(elapsed, cube);
      if (transfer <= 0) continue;
      final flow = _messageParticleFlow(elapsed, particle);
      final sourceCenter = _messageProject(
        transforms[particle.sourceId],
        elapsed,
      ).offset;
      final faceAngle = cube.spin + particle.index * 1.71;
      final source =
          sourceCenter +
          Offset(math.cos(faceAngle), math.sin(faceAngle)) *
              (cube.size * (.11 + particle.depth * .06));
      final target = _messageProject(particle.target, elapsed).offset;
      final travel = target - source;
      final travelLength = travel.distance;
      final tangent = travelLength == 0
          ? Offset.zero
          : Offset(-travel.dy / travelLength, travel.dx / travelLength) *
                (10 + particle.depth * 15);
      final swirl =
          Offset(
            math.cos(faceAngle * 1.9) * (8 + particle.depth * 8),
            math.sin(faceAngle * 1.9) * (8 + particle.depth * 8),
          ) *
          (1 - flow);
      final position = _messageBezier(
        source,
        source + tangent + swirl,
        target - tangent * .42 + swirl * .35,
        target,
        flow,
      );
      final color = switch ((cube.id + particle.index) % 4) {
        0 => const Color(0xffb5f3ff),
        1 => const Color(0xff85ffe1),
        2 => const Color(0xff7ea8ff),
        _ => const Color(0xff63d8ff),
      };
      final visible = _ease(_phase(transfer, 0, .35));
      // The travelling field dissipates once it has reached the local word
      // surface. The final phrase is therefore smooth material, never a
      // frozen dot-matrix copy of the former cube targets.
      final alpha =
          (.35 + flow * .42) *
          visible *
          (1 - _ease(_phase(elapsed, 3600, 4350)));
      final size = particle.size * (.8 + particle.depth * .32);
      // Only a representative sixth receives blur; the majority remain
      // inexpensive square/point material rather than a full-screen glow.
      if ((cube.id + particle.index) % 6 == 0) {
        canvas.drawCircle(
          position,
          size * 2.6,
          _glow(color.withValues(alpha: alpha * .34), 3.2, 2.4),
        );
      }
      canvas.drawRect(
        Rect.fromCenter(
          center: position,
          width: size * 1.7,
          height: size * 1.7,
        ),
        _fill(color.withValues(alpha: alpha)),
      );
    }
  }

  _MessageWordLayout _messageWordLayout(String modeName) {
    final painter = TextPainter(
      text: TextSpan(
        text: sandboxMessageAssemblyMessage(modeName),
        style: const TextStyle(
          color: Color(0xffffffff),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: .9,
          fontFamily: 'MPlus1Code',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return _MessageWordLayout(
      text: sandboxMessageAssemblyMessage(modeName),
      width: painter.width,
      height: painter.height,
      finalScale: math.min(1, 286 / painter.width),
    );
  }

  void _paintMessageWordSurface(
    Canvas canvas,
    String modeName,
    double elapsed,
  ) {
    final word = _messageWordLayout(modeName);
    final pullBack = _ease(_phase(elapsed, 3450, 5650));
    final reveal = sandboxMessageSurfaceReveal(elapsed);
    final zoom = sandboxMessageCameraZoom(elapsed);
    final roll = sandboxMessageScreenRoll(elapsed) * math.pi / 180;
    final yaw = (58 * (1 - pullBack)) * math.pi / 180;
    final focusX = word.width * (.10 + .40 * pullBack);
    final surfaceAlpha = _ease(_phase(elapsed, 3150, 5200));
    final emission = 1 - _ease(_phase(elapsed, 5000, 5900));
    final visibleWidth = word.width * reveal;

    canvas.save();
    canvas.translate(180, 140);
    canvas.rotate(roll);
    // The compressed horizontal axis and stepped side layers supply an
    // oblique, shallow-extruded word volume until it faces the camera.
    canvas.scale(
      zoom * word.finalScale * math.cos(yaw),
      zoom * word.finalScale,
    );
    canvas.translate(-focusX, -word.height / 2);
    canvas.clipRect(Rect.fromLTWH(0, 0, visibleWidth, word.height));

    final sideCount = 3;
    for (var layer = sideCount; layer > 0; layer--) {
      final fraction = layer / sideCount;
      _paintMessageWordText(
        canvas,
        word.text,
        Offset(fraction * 3.2, fraction * 2.6),
        Color.lerp(
          const Color(0xff134b55),
          const Color(0xff67bdab),
          fraction,
        )!.withValues(alpha: surfaceAlpha * (.10 + emission * .42)),
      );
    }
    _paintMessageWordText(
      canvas,
      word.text,
      Offset.zero,
      Color.lerp(
        const Color(0xff76e6d9),
        const Color(0xffd8fbff),
        1 - emission * .38,
      )!.withValues(alpha: surfaceAlpha),
    );

    // Fine deterministic glints adhere to the very same local word space.
    // They create the material-forming illusion while the smooth surface is
    // progressively uncovered beneath them.
    final particleAlpha = surfaceAlpha * (.22 + emission * .55);
    final particleCount = 180;
    for (var index = 0; index < particleCount; index++) {
      final unitX = _particleUnit(443, index, 1);
      final unitY = _particleUnit(443, index, 2);
      if (unitX > reveal) continue;
      final flow = _ease(_phase(elapsed, 3050 + (index % 19) * 24, 4900));
      final x = unitX * word.width;
      final y = unitY * word.height;
      final offset = Offset(
        math.sin(index * 1.71 + elapsed / 190) * (1 - flow) * 7,
        math.cos(index * 1.13 + elapsed / 230) * (1 - flow) * 5,
      );
      final point = Offset(x, y) + offset;
      final radius = .55 + (index % 4) * .19;
      final color = index.isEven ? _ice : const Color(0xff92f5df);
      if (index % 9 == 0) {
        canvas.drawCircle(
          point,
          radius * 3,
          _glow(color.withValues(alpha: particleAlpha * .38), 2.8, 1.6),
        );
      }
      canvas.drawCircle(
        point,
        radius,
        _fill(color.withValues(alpha: particleAlpha)),
      );
    }
    canvas.restore();
  }

  void _paintMessageWordText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: .9,
          fontFamily: 'MPlus1Code',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  SandboxProjectedPoint _messageProject(SandboxVec3 point, double elapsed) =>
      _MessageProjection(elapsed).project(
        point
            .rotateY(_messageWorldYaw(elapsed))
            .rotateX(_messageWorldPitch(elapsed)),
      );

  double _messageImpactIntensity(double elapsed) =>
      _ease(_phase(elapsed, 850, 930)) *
      (1 - _ease(_phase(elapsed, 1080, 1300)));

  double _messageEdgePulse(
    double elapsed,
    SandboxMessageNetworkEdge edge,
    int index,
  ) {
    final start = 1120 + edge.wave * 260 + (index % 7) * 44.0;
    return _phase(elapsed, start, start + 190 + (index % 4) * 20);
  }

  double _messageEdgeStrength(
    double elapsed,
    SandboxMessageNetworkEdge edge,
    int index,
  ) {
    final start = 1120 + edge.wave * 260 + (index % 7) * 44.0;
    final duration = 190 + (index % 4) * 20.0;
    return 1 - _ease(_phase(elapsed, start + duration, start + duration + 420));
  }

  double _messageWorldYaw(double elapsed) {
    final frontal = _ease(_phase(elapsed, 3000, 4700));
    return -25 * (1 - frontal) * math.pi / 180;
  }

  double _messageWorldPitch(double elapsed) =>
      (18 - 18 * _ease(_phase(elapsed, 3000, 4700))) * math.pi / 180;

  void _assemblyMatrix(Canvas canvas, double t, double post) {
    const process = Offset(180, 140);
    const source = Offset(55, 140);
    const destination = Offset(307, 140);
    final isSave = operation == TransferOperation.save;
    final transfer = isSave ? _phase(t, .60, .867) : _phase(t, .45, .80);
    final terminalScale = isSave ? 1 - .48 * _ease(transfer) : 1.0;
    final terminalCenter = isSave
        ? Offset.lerp(process, destination, _ease(transfer))!
        : process;
    _sourceDevice(canvas, source, active: t < (isSave ? .60 : .80));
    if (isSave) {
      _storageBay(
        canvas,
        destination,
        fill: _phase(t, .60, .90),
        locked: t >= 1,
      );
    } else {
      _receiver(
        canvas,
        destination,
        fill: _phase(t, .80, .933),
        acknowledged: t >= .933,
      );
    }
    final projection = SandboxProjection(terminalCenter);
    SandboxVec3 orient(SandboxVec3 point) => (point * terminalScale)
        .rotateX((-22 + 4 * math.sin(post * math.pi * 2 / 4.6)) * math.pi / 180)
        .rotateY((30 + 5 * math.sin(post * math.pi * 2 / 4)) * math.pi / 180);
    final faces = <_RenderFace>[];
    for (var index = 0; index < 36; index++) {
      final pressed = isSave
          ? _phase(
              t,
              .133 + index * (.317 / 36),
              .133 + (index + 1) * (.317 / 36),
            )
          : 1.0;
      final center =
          sandboxMatrixModuleCenters()[index] +
          SandboxVec3(
            0,
            0,
            -2.5 *
                (pressed > 0 && pressed < 1 ? math.sin(pressed * math.pi) : 0),
          );
      final color = (isSave && transfer > 0 && index < (transfer * 36).floor())
          ? const Color(0xff315263)
          : _cyan.withValues(alpha: .9);
      for (final face in sandboxRectangularPrismFaces(center, 13, 13, 5)) {
        faces.add(
          _RenderFace(
            face.vertices.map(orient).toList(),
            orient(face.normal),
            color,
          ),
        );
      }
    }
    _paint3dFaces(
      canvas,
      projection,
      faces,
      border: _ice.withValues(alpha: .75),
    );
    final links = sandboxMatrixAdjacencyLinks();
    final linkProgress = isSave ? _phase(t, .45, .60) : _phase(t, .15, .45);
    for (
      var index = 0;
      index < (links.length * linkProgress).floor();
      index++
    ) {
      final link = links[index];
      canvas.drawLine(
        projection
            .project(orient(sandboxMatrixModuleCenters()[link.$1]))
            .offset,
        projection
            .project(orient(sandboxMatrixModuleCenters()[link.$2]))
            .offset,
        _line(_ice.withValues(alpha: .52), .7),
      );
    }
    if (isSave) {
      for (var lane = 0; lane < 6; lane++) {
        final laneOffset = Offset(0, (lane - 2.5) * 5);
        _packet(
          canvas,
          Offset.lerp(
                source,
                terminalCenter,
                _phase(t + lane * .03, 0, .133),
              )! +
              laneOffset,
          color: _ice,
        );
        if (transfer > 0) {
          _packet(
            canvas,
            Offset.lerp(
                  process,
                  destination,
                  (transfer + lane * .13).remainder(1),
                )! +
                laneOffset,
            color: _cyan,
          );
        }
      }
    } else {
      for (var lane = 0; lane < 6; lane++) {
        final laneOffset = Offset(0, (lane - 2.5) * 5);
        if (transfer > 0) {
          _packet(
            canvas,
            Offset.lerp(
                  process,
                  destination,
                  (transfer + lane * .12).remainder(1),
                )! +
                laneOffset,
            color: _ice,
          );
        }
      }
      if (t >= .933) {
        _packet(
          canvas,
          Offset.lerp(destination, source, _phase(t, .933, 1))!,
          color: const Color(0xff8af6e9),
        );
      }
    }
    _center(
      canvas,
      isSave ? 'MATRIX / ARCHIVE WRITE' : 'MATRIX / SIX STREAM READ',
      const Offset(180, 79),
      7,
      _ice,
    );
  }

  void _voxelIntegration(Canvas canvas, double t, double post) {
    final fragmentsEnd = sandboxPixelVoxelFragmentsEndMs(pixelBuilderFinale);
    final elapsedMs =
        t * sandboxPixelVoxelCycle(pixelBuilderFinale).inMilliseconds;
    if (elapsedMs < fragmentsEnd) {
      _pixelBuilder(canvas, elapsedMs);
      return;
    }

    // Pixel fragments end at exactly the V3.2 source coordinates.  The
    // original 6000ms voxel construction then starts without acceleration.
    final local = ((elapsedMs - fragmentsEnd) / _cycle.inMilliseconds)
        .clamp(0, 1)
        .toDouble();
    const sceneCenter = Offset(181, 143);
    final projection = SandboxProjection(sceneCenter);
    final centers = sandboxVoxelCenters();
    final crystallize = _ease(_phase(local, 3700 / 6000, 4400 / 6000));
    final sourceMaterialize = _ease(_phase(local, 0, 280 / 6000));
    final lift = _ease(_phase(local, 4400 / 6000, 5000 / 6000));
    // The controller uses the same ceiling boundary as the renderer. The
    // explicit terminal-frame branch prevents a fractional end timestamp from
    // suppressing completed rotation, label, and particle state.
    final complete =
        t >= 1 ||
        sandboxPixelVoxelConstructionComplete(elapsedMs, pixelBuilderFinale);
    final yaw = complete ? post * 22 * math.pi / 180 : 0.0;
    final pitch = complete
        ? math.sin(post * 2 * math.pi / 3) * 6 * math.pi / 180
        : 0.0;
    final hover = complete ? math.sin(post * 2 * math.pi / 3.2) * 3 : 0.0;
    final rise = 23 * lift + hover;
    final emission = local >= 4400 / 6000 && local < 4700 / 6000
        ? .52
        : complete
        ? .28
        : crystallize > 0
        ? .22 + crystallize * .2
        : .22;
    _text(
      canvas,
      'VOXEL CHAMBER / 3x3x3',
      const Offset(108, 75),
      8,
      const Color(0xffb0e6ff),
    );
    final faces = <_RenderFace>[];
    for (var index = 0; index < centers.length; index++) {
      final travelStart = 1100 / 6000 + index * (45 / 6000);
      final travel = _ease(
        _phase(local, travelStart, travelStart + 700 / 6000),
      );
      final source = sandboxVoxelSource(index);
      final target = centers[index] * (1 - crystallize * (2 / 24));
      var position = SandboxVec3.lerp(source, target, travel);
      final previous = SandboxVec3.lerp(
        source,
        target,
        math.max(0, travel - .12),
      );
      position = (position + SandboxVec3(0, rise, 0))
          .rotateY(yaw)
          .rotateX(pitch);
      final base = sandboxVoxelColorForIndex(
        centers[index],
        index,
      ).withValues(alpha: .84);
      if (travel > 0 && travel < 1) {
        canvas.drawLine(
          projection.project(previous).offset,
          projection.project(position).offset,
          _glow(base.withValues(alpha: .18 * (1 - travel)), 2.5, 1.4),
        );
      }
      final side = 4 + (22 - 4) * sourceMaterialize;
      for (final face in sandboxCubeFaces(position, side)) {
        faces.add(_RenderFace(face.vertices, face.normal, base));
      }
      final projected = projection.project(position);
      canvas.drawCircle(
        projected.offset,
        4.5,
        _glow(base.withValues(alpha: emission), 5, 5),
      );
      canvas.drawCircle(
        projected.offset,
        2.2,
        _glow(_ice.withValues(alpha: emission), 2.5, 2.5),
      );
    }
    _paint3dFaces(
      canvas,
      projection,
      faces,
      border: _ice.withValues(alpha: .84),
    );
    if (complete) {
      _voxelCompletionLabel(canvas, post);
    }
  }

  void _pixelBuilder(Canvas canvas, double elapsedMs) {
    const barY = 158.0;
    final loadingEnd = sandboxPixelBuilderLoadingEndMs(pixelBuilderFinale);
    final visible = _phase(elapsedMs, 0, _pixelBuilderInitialMs);
    final fragmentation = _phase(elapsedMs, loadingEnd, loadingEnd + 200);
    final filled = sandboxPixelBuilderFilledSegments(
      elapsedMs.round(),
      finale: pixelBuilderFinale,
    );
    _center(
      canvas,
      'PIXEL BUILDER',
      const Offset(180, 100),
      10,
      _ice.withValues(alpha: visible),
    );
    for (var index = 0; index < 10; index++) {
      final rect = sandboxPixelBuilderSegmentRect(index);
      final local = _pixelBuilderLocalMs(elapsedMs, index);
      final active = index == 9
          ? elapsedMs >= _pixelBuilderFinalActStartMs && elapsedMs < loadingEnd
          : elapsedMs >= sandboxPixelBuilderCycleStartMs(index) &&
                elapsedMs <
                    sandboxPixelBuilderCycleStartMs(index) +
                        _pixelBuilderCycleMs;
      final flash = index < 9 && active && local >= 350 && local < 395
          ? 1 - _phase(local, 350, 395)
          : 0.0;
      final color = index < filled
          ? const Color(0xff63d8ff)
          : const Color(0xff243d50);
      canvas.drawRect(rect, _fill(color.withValues(alpha: 1 - fragmentation)));
      canvas.drawRect(
        rect,
        _line(
          (active || index < filled ? const Color(0xffbff6ff) : _cyan)
              .withValues(alpha: .65 * (1 - fragmentation)),
          .8,
        ),
      );
      if (flash > 0) {
        canvas.drawRect(
          rect.deflate(2),
          _fill(const Color(0xffbff6ff).withValues(alpha: flash)),
        );
      }
    }
    _center(
      canvas,
      '${(filled * 10).clamp(0, 100)}%',
      const Offset(180, 188),
      8,
      _ice,
    );
    if (elapsedMs < loadingEnd) {
      _pixelBuilderRobot(canvas, elapsedMs, visible);
    }
    if (elapsedMs >= loadingEnd) {
      _pixelFragments(canvas, elapsedMs);
    }
    // A small synchronized confirmation once the robot has become the final
    // module. It fades before the physical data-fragment handoff begins.
    if (elapsedMs >= loadingEnd - 160 && elapsedMs < loadingEnd) {
      final alpha = _phase(elapsedMs, loadingEnd - 160, loadingEnd);
      canvas.drawLine(
        const Offset(56, barY - 2),
        const Offset(274, barY - 2),
        _glow(_ice.withValues(alpha: .6 * alpha), 3, 1.4),
      );
    }
  }

  void _pixelBuilderRobot(Canvas canvas, double elapsedMs, double visibility) {
    if (elapsedMs >= _pixelBuilderFinalActStartMs) {
      _pixelBuilderFinalActRobot(canvas, elapsedMs, visibility);
      return;
    }
    final hesitation =
        elapsedMs >= _pixelBuilderHesitationStartMs &&
        elapsedMs < _pixelBuilderHesitationEndMs;
    final index = hesitation
        ? 5
        : List<int>.generate(9, (value) => value).lastWhere(
            (value) => elapsedMs >= sandboxPixelBuilderCycleStartMs(value),
            orElse: () => 0,
          );
    final local = _pixelBuilderLocalMs(elapsedMs, index);
    final previousX = 64.5 + 22 * math.max(0, index - 1);
    final targetX = 64.5 + 22 * index;
    final move = _phase(local, 0, 45);
    var centerX = previousX + (targetX - previousX) * _ease(move);
    if (elapsedMs < _pixelBuilderInitialMs) centerX = 64.5;
    final strikeCount = sandboxPixelBuilderStrikeCount(index);
    final striking = !hesitation && local >= 70 && local < 350;
    final strikeDuration = 280 / strikeCount;
    final strikeLocal = (local - 70).clamp(0, 280).toDouble();
    final strikeProgress = striking
        ? (strikeLocal % strikeDuration) / strikeDuration
        : 0.0;
    final armContact = striking ? math.sin(math.pi * strikeProgress) : 0.0;
    final finalFlash = !hesitation && local >= 350 && local < 395;
    final alpha = visibility;
    final hesitationPhase = _phase(
      elapsedMs,
      _pixelBuilderHesitationStartMs,
      _pixelBuilderHesitationEndMs,
    );
    final toolAdjust =
        hesitation && hesitationPhase >= .52 && hesitationPhase < .82
        ? math.sin((hesitationPhase - .52) / .30 * math.pi * 4) * 2
        : 0.0;
    final bodyBottom = 154.0 + armContact * 2;
    final headTilt =
        hesitation && hesitationPhase >= .2 && hesitationPhase < .52
        ? 2.0
        : 0.0;
    final eyeFlicker =
        hesitation && hesitationPhase >= .2 && hesitationPhase < .52;
    final armY = hesitation
        ? bodyBottom - 8 + toolAdjust
        : bodyBottom - 8 + armContact * 12;
    final stride = local < 70 ? (local / 70) * 2 : 0.0;
    if (robotAppearance == SandboxRobotAppearance.original) {
      _paintOriginalPixelRobot(
        canvas,
        centerX: centerX,
        bodyBottom: bodyBottom,
        alpha: alpha,
        stride: stride,
        armY: armY,
        completion: false,
        headTilt: headTilt,
        eyeFlicker: eyeFlicker,
      );
    } else {
      _paintArkPixelRobot(
        canvas,
        centerX: centerX,
        bodyBottom: bodyBottom,
        alpha: alpha,
        stride: stride,
        armY: armY,
        completion: false,
        headTilt: headTilt,
        eyeFlicker: eyeFlicker,
      );
    }
    if (striking && armContact > .87) {
      _pixelSparks(canvas, Offset(centerX + 11, 158), alpha * armContact);
    }
    if (finalFlash) {
      _pixelSparks(canvas, Offset(centerX + 11, 158), alpha);
    }
  }

  /// The final block gets a short character beat: inspect it, walk beside it,
  /// lose balance, then land and compact into that exact cell. Keeping the
  /// motion on the common timeline makes replay and the ARK variant
  /// deterministic.
  void _pixelBuilderFinalActRobot(
    Canvas canvas,
    double elapsedMs,
    double visibility,
  ) {
    final local = elapsedMs - _pixelBuilderFinalActStartMs;
    final last = sandboxPixelBuilderSegmentRect(9);
    final stage = sandboxPixelBuilderFinalAct(
      elapsedMs.round(),
      finale: pixelBuilderFinale,
    );
    final walkIn = pixelBuilderFinale == SandboxPixelBuilderFinale.walkIn;
    final finalActDuration = sandboxPixelBuilderFinalActDurationMs(
      pixelBuilderFinale,
    );
    final walk = _ease(_phase(local, 300, walkIn ? 770 : 590));
    final wobble = _phase(local, 590, 770);
    final fall = _ease(_phase(local, 770, 950));
    final settle = _phase(local, 950, finalActDuration);
    final previousCenterX = last.center.dx - 22;
    final walkingCenterX =
        previousCenterX + (last.center.dx - previousCenterX) * walk;
    final wobbleOffset = stage == SandboxPixelBuilderFinalAct.wobbling
        ? math.sin(wobble * math.pi * 3) * 3
        : 0.0;
    final centerX = stage == SandboxPixelBuilderFinalAct.looking
        ? previousCenterX
        : stage == SandboxPixelBuilderFinalAct.walking
        ? walkingCenterX
        : last.center.dx + wobbleOffset;
    // Feet travel down to the final cell's lower boundary; the final compact
    // shape is drawn with that same cell rect below, eliminating the former
    // apparent split between the fall and the completed gauge block.
    final integration = _ease(_phase(local, 770, walkIn ? 900 : 950));
    final bodyBottom = walkIn
        ? 154 + (last.bottom - 154) * integration
        : 154 + (last.bottom - 154) * fall;
    final transform = walkIn ? _phase(local, 770, 900) : settle;
    final alpha = visibility * (1 - transform);
    final armY = stage == SandboxPixelBuilderFinalAct.looking
        ? bodyBottom - 6
        : stage == SandboxPixelBuilderFinalAct.walking
        ? bodyBottom - 8
        : bodyBottom - (walkIn ? 8 : 13);
    final stride = stage == SandboxPixelBuilderFinalAct.walking
        ? math.sin(walk * math.pi * 3) * 2
        : 0.0;
    final headTilt = stage == SandboxPixelBuilderFinalAct.looking
        ? 1.5
        : stage == SandboxPixelBuilderFinalAct.wobbling
        ? math.sin(wobble * math.pi * 3) * 3
        : stage == SandboxPixelBuilderFinalAct.falling
        ? fall * 4
        : 0.0;
    if (robotAppearance == SandboxRobotAppearance.original) {
      _paintOriginalPixelRobot(
        canvas,
        centerX: centerX,
        bodyBottom: bodyBottom,
        alpha: alpha,
        stride: stride,
        armY: armY,
        completion: false,
        headTilt: headTilt,
        eyeFlicker: stage == SandboxPixelBuilderFinalAct.looking,
      );
    } else {
      _paintArkPixelRobot(
        canvas,
        centerX: centerX,
        bodyBottom: bodyBottom,
        alpha: alpha,
        stride: stride,
        armY: armY,
        completion: false,
        headTilt: headTilt,
        eyeFlicker: stage == SandboxPixelBuilderFinalAct.looking,
      );
    }
    if (!walkIn && stage == SandboxPixelBuilderFinalAct.falling && fall > .55) {
      _pixelSparks(canvas, Offset(last.center.dx, last.top), alpha * .35);
    }
    final faceOpacity = walkIn
        ? _phase(local, 870, 900) * (1 - _phase(local, 1180, 1350))
        : 0.0;
    if (faceOpacity > 0) {
      // The same authoritative segment rect contains the compressed robot
      // face; no independent tile coordinates can drift from the gauge.
      canvas.drawRect(
        last.deflate(1.25),
        _fill(const Color(0xff102a38).withValues(alpha: faceOpacity)),
      );
      canvas.drawRect(
        last,
        _line(const Color(0xffbff6ff).withValues(alpha: faceOpacity), .8),
      );
      final eyeOffset = _walkInEyeOffset(local);
      for (final dx in [-3.2, 3.2]) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(last.center.dx + dx + eyeOffset, last.center.dy),
            width: 2.1,
            height: 2.1,
          ),
          _fill(const Color(0xffddffff).withValues(alpha: faceOpacity)),
        );
      }
    }
    final cellProgress = walkIn ? _phase(local, 1180, 1350) : settle;
    if (cellProgress > 0) {
      // Match the bar's existing full cell dimensions, center, and border.
      // The compacting robot fades only as this exact gauge cell appears.
      canvas.drawRect(
        last,
        _fill(const Color(0xff63d8ff).withValues(alpha: cellProgress)),
      );
      canvas.drawRect(
        last,
        _line(const Color(0xffbff6ff).withValues(alpha: cellProgress), .8),
      );
    }
  }

  double _walkInEyeOffset(double local) {
    if (local < 940) return 0;
    if (local < 980) return -1.8 * _ease(_phase(local, 940, 980));
    if (local < 1030) return -1.8;
    if (local < 1090) {
      return -1.8 + 3.6 * _ease(_phase(local, 1030, 1090));
    }
    if (local < 1140) return 1.8;
    if (local < 1180) return 1.8 * (1 - _ease(_phase(local, 1140, 1180)));
    return 0;
  }

  void _paintOriginalPixelRobot(
    Canvas canvas, {
    required double centerX,
    required double bodyBottom,
    required double alpha,
    required double stride,
    required double armY,
    required bool completion,
    required double headTilt,
    required bool eyeFlicker,
  }) {
    final head = Rect.fromCenter(
      center: Offset(centerX + headTilt, bodyBottom - 20),
      width: 20,
      height: 15,
    );
    final body = Rect.fromCenter(
      center: Offset(centerX, bodyBottom - 8),
      width: 13,
      height: 9,
    );
    final outline = const Color(0xff93dcf0).withValues(alpha: alpha);
    canvas.drawRect(
      head,
      _fill(const Color(0xff315f7d).withValues(alpha: alpha)),
    );
    canvas.drawRect(head, _line(outline, 1));
    canvas.drawRect(
      body,
      _fill(const Color(0xff315f7d).withValues(alpha: alpha)),
    );
    canvas.drawRect(body, _line(outline, 1));
    for (final dx in [-4.0, 4.0]) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(centerX + dx, bodyBottom - 20),
          width: 2.5,
          height: 2.5,
        ),
        _fill(
          (eyeFlicker ? const Color(0xffbff6ff) : const Color(0xffddffff))
              .withValues(alpha: alpha),
        ),
      );
    }
    for (final entry in [(-4.0, stride), (4.0, -stride)]) {
      canvas.drawLine(
        Offset(centerX + entry.$1, bodyBottom - 4),
        Offset(centerX + entry.$1 + entry.$2, bodyBottom),
        _line(const Color(0xff97bfe6).withValues(alpha: alpha), 2),
      );
    }
    final armStart = Offset(centerX + 7, bodyBottom - 10);
    final armEnd = Offset(centerX + 11, armY);
    canvas.drawLine(armStart, armEnd, _line(outline, 2));
    canvas.drawRect(
      Rect.fromCenter(center: armEnd, width: 3, height: 3),
      _fill(const Color(0xffb9f8ff).withValues(alpha: alpha)),
    );
    if (completion) {
      // A second raised arm during the one-time celebration.
      canvas.drawLine(
        Offset(centerX - 7, bodyBottom - 10),
        Offset(centerX - 11, bodyBottom - 17),
        _line(outline, 2),
      );
    }
  }

  void _pixelSparks(Canvas canvas, Offset origin, double alpha) {
    for (final entry in const [Offset(-3, -4), Offset(2, -5), Offset(4, -1)]) {
      canvas.drawRect(
        Rect.fromCenter(center: origin + entry, width: 2, height: 2),
        _fill(const Color(0xffbff6ff).withValues(alpha: alpha)),
      );
    }
  }

  void _paintArkPixelRobot(
    Canvas canvas, {
    required double centerX,
    required double bodyBottom,
    required double alpha,
    required double stride,
    required double armY,
    required bool completion,
    required double headTilt,
    required bool eyeFlicker,
  }) {
    final outline = const Color(0xff93dcf0).withValues(alpha: alpha);
    final hood = Path()
      ..moveTo(centerX - 10 + headTilt, bodyBottom - 28)
      ..lineTo(centerX - 6 + headTilt, bodyBottom - 32)
      ..lineTo(centerX + 7 + headTilt, bodyBottom - 32)
      ..lineTo(centerX + 11 + headTilt, bodyBottom - 27)
      ..lineTo(centerX + 10 + headTilt, bodyBottom - 15)
      ..lineTo(centerX - 10 + headTilt, bodyBottom - 15)
      ..close();
    canvas.drawPath(
      hood,
      _fill(const Color(0xff315f7d).withValues(alpha: alpha)),
    );
    canvas.drawPath(hood, _line(outline, 1));
    final face = Rect.fromCenter(
      center: Offset(centerX + headTilt, bodyBottom - 23),
      width: 15,
      height: 8,
    );
    canvas.drawRect(
      face,
      _fill(const Color(0xff0c202d).withValues(alpha: alpha)),
    );
    for (final dx in [-3.0, 3.0]) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(centerX + headTilt + dx, bodyBottom - 23),
          width: 2.5,
          height: 2.5,
        ),
        _fill(
          (eyeFlicker ? const Color(0xffbff6ff) : const Color(0xffddffff))
              .withValues(alpha: alpha),
        ),
      );
    }
    final robe = Path()
      ..moveTo(centerX - 6, bodyBottom - 16)
      ..lineTo(centerX + 6, bodyBottom - 16)
      ..lineTo(centerX + 10, bodyBottom - 4)
      ..lineTo(centerX - 10, bodyBottom - 4)
      ..close();
    canvas.drawPath(
      robe,
      _fill(const Color(0xff315f7d).withValues(alpha: alpha)),
    );
    canvas.drawPath(robe, _line(outline, 1));
    for (final entry in [(-4.0, stride), (4.0, -stride)]) {
      canvas.drawLine(
        Offset(centerX + entry.$1, bodyBottom - 4),
        Offset(centerX + entry.$1 + entry.$2, bodyBottom),
        _line(const Color(0xff97bfe6).withValues(alpha: alpha), 2),
      );
    }
    final armStart = Offset(centerX + 7, bodyBottom - 12);
    final armEnd = Offset(centerX + 11, armY);
    canvas.drawLine(armStart, armEnd, _line(outline, 2));
    _arkWrench(canvas, armEnd, alpha);
    if (completion) {
      canvas.drawLine(
        Offset(centerX - 7, bodyBottom - 12),
        Offset(centerX - 11, bodyBottom - 18),
        _line(outline, 2),
      );
    }
  }

  /// An open-ended C jaw faces right. It deliberately has no middle prong.
  void _arkWrench(Canvas canvas, Offset origin, double alpha) {
    final paint = _line(const Color(0xffb9f8ff).withValues(alpha: alpha), 1.8);
    canvas.drawLine(origin, origin + const Offset(6, 0), paint);
    final jaw = Path()
      ..moveTo(origin.dx + 10, origin.dy - 5)
      ..lineTo(origin.dx + 6, origin.dy - 5)
      ..lineTo(origin.dx + 4, origin.dy - 3)
      ..lineTo(origin.dx + 4, origin.dy + 3)
      ..lineTo(origin.dx + 6, origin.dy + 5)
      ..lineTo(origin.dx + 10, origin.dy + 5);
    canvas.drawPath(jaw, paint);
  }

  void _pixelFragments(Canvas canvas, double elapsedMs) {
    final loadingEnd = sandboxPixelBuilderLoadingEndMs(pixelBuilderFinale);
    final fragmentsEnd = sandboxPixelVoxelFragmentsEndMs(pixelBuilderFinale);
    final detach = _phase(elapsedMs, loadingEnd, loadingEnd + 200);
    final scatter = _ease(_phase(elapsedMs, loadingEnd + 200, fragmentsEnd));
    final projection = const SandboxProjection(Offset(181, 143));
    for (var index = 0; index < sandboxPixelFragmentCount; index++) {
      final source = sandboxPixelFragmentSource(index);
      final target = projection.project(sandboxVoxelSource(index)).offset;
      final detachOffset = Offset(
        ((index % 3) - 1) * 3 * detach,
        ((index % 4) - 1.5) * 2 * detach,
      );
      final position = Offset.lerp(source + detachOffset, target, scatter)!;
      final color = sandboxVoxelColorForIndex(
        sandboxVoxelCenters()[index],
        index,
      );
      canvas.drawRect(
        Rect.fromCenter(center: position, width: 4, height: 4),
        _fill(color.withValues(alpha: .92)),
      );
      canvas.drawRect(
        Rect.fromCenter(center: position, width: 4, height: 4),
        _line(_ice.withValues(alpha: .7), .55),
      );
    }
  }

  void _voxelCompletionLabel(Canvas canvas, double post) {
    final iconAlpha = reducedMotion ? 1.0 : _phase(post, 0, .2);
    final textAlpha = reducedMotion ? 1.0 : _phase(post, .2, .45);
    final text = _voxelCompletionMessage(mode, operation);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _ice.withValues(alpha: textAlpha),
          fontSize: 8,
          fontFamily: 'ShareTechMono',
          letterSpacing: .45,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const iconSize = 13.0;
    const gap = 4.0;
    final left = 181 - (iconSize + gap + painter.width) / 2;
    _completionIcon(
      canvas,
      Offset(left + iconSize / 2, 202),
      archive: mode == _OperationMode.backup,
      alpha: iconAlpha,
    );
    painter.paint(
      canvas,
      Offset(left + iconSize + gap, 202 - painter.height / 2),
    );
  }

  void _completionIcon(
    Canvas canvas,
    Offset center, {
    required bool archive,
    required double alpha,
  }) {
    final color = _ice.withValues(alpha: alpha);
    if (!archive) {
      final document = Rect.fromCenter(center: center, width: 10, height: 12);
      canvas.drawRect(document, _line(color, 1));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(center.dx, document.top + 1.2),
            width: 4,
            height: 2.4,
          ),
          const Radius.circular(.6),
        ),
        _line(color, 1),
      );
      for (final y in [
        document.top + 5,
        document.top + 7.4,
        document.top + 9.8,
      ]) {
        canvas.drawLine(
          Offset(document.left + 2, y),
          Offset(document.right - 2, y),
          _line(color, .8),
        );
      }
      return;
    }
    final hexagon = Path();
    for (var index = 0; index < 6; index++) {
      final angle = -math.pi / 2 + index * math.pi / 3;
      final point = center + Offset(math.cos(angle) * 6, math.sin(angle) * 6);
      if (index == 0) {
        hexagon.moveTo(point.dx, point.dy);
      } else {
        hexagon.lineTo(point.dx, point.dy);
      }
    }
    hexagon.close();
    canvas.drawPath(hexagon, _line(color, 1));
    canvas.drawCircle(center, 1.5, _fill(color));
    for (final y in [-2.5, 2.5]) {
      canvas.drawLine(
        Offset(center.dx - 3, center.dy + y),
        Offset(center.dx + 3, center.dy + y),
        _line(color, .75),
      );
    }
  }

  void _polyhedralFold(Canvas canvas, double t, double post) {
    const process = Offset(180, 140);
    const source = Offset(55, 140);
    const destination = Offset(307, 140);
    final isSave = operation == TransferOperation.save;
    final fuse = isSave ? _phase(t, .133, .483) : _phase(t, .133, .467);
    final transfer = isSave ? _phase(t, .583, .883) : _phase(t, .533, .817);
    final center = Offset.lerp(process, destination, _ease(transfer))!;
    final scale = 1 - .5 * _ease(transfer);
    _sourceDevice(canvas, source, active: t < (isSave ? .583 : .817));
    if (isSave) {
      _storageBay(
        canvas,
        destination,
        fill: _phase(t, .883, 1),
        locked: t >= 1,
      );
    } else {
      _receiver(
        canvas,
        destination,
        fill: _phase(t, .817, .933),
        acknowledged: t >= .933,
      );
    }
    final projection = SandboxProjection(center);
    final faces = <_RenderFace>[];
    final open = !isSave && t >= .817 ? _phase(t, .817, .933) : 0.0;
    for (final entry in sandboxFusionCubeFaces(fuse).asMap().entries) {
      final face = entry.value.transform((point) => point * scale);
      final separated = open == 0 ? face : _separateFace(face, open * 26);
      faces.add(
        _RenderFace(
          separated.vertices,
          separated.normal,
          Color.lerp(
            _cyan,
            _violet,
            (entry.key % 3) / 3,
          )!.withValues(alpha: .76 * (1 - .55 * open)),
        ),
      );
    }
    // SEND opens the transport shell after capture, while the core remains
    // visibly resident in the receiver rather than disappearing at ACK.
    final coreAlpha = 1.0;
    if (coreAlpha > 0) {
      canvas.drawCircle(
        projection.project(SandboxVec3.zero).offset,
        8 * scale,
        _glow(_ice.withValues(alpha: .45 * coreAlpha), 4, 8 * scale),
      );
      canvas.drawCircle(
        projection.project(SandboxVec3.zero).offset,
        5 * scale,
        _fill(_ice.withValues(alpha: .9 * coreAlpha)),
      );
    }
    _paint3dFaces(
      canvas,
      projection,
      faces,
      border: _ice.withValues(alpha: .9),
    );
    if (!isSave && t >= .933) {
      _packet(
        canvas,
        Offset.lerp(destination, source, _phase(t, .933, 1))!,
        color: const Color(0xff8af6e9),
      );
    }
    _center(
      canvas,
      isSave ? 'SEALED CORE / ARCHIVE' : 'CORE / REMOTE RECEIVE',
      const Offset(180, 79),
      7,
      _ice,
    );
  }

  SandboxFace _separateFace(SandboxFace face, double distance) {
    return face.transform((point) => point + face.normal * distance);
  }

  void _sourceDevice(Canvas canvas, Offset center, {required bool active}) {
    final rect = Rect.fromCenter(center: center, width: 48, height: 50);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      _fill(const Color(0xff0b1d29)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      _line(_cyan.withValues(alpha: active ? .8 : .3), 1),
    );
    _center(canvas, 'SOURCE', center + const Offset(0, -16), 6.5, _ice);
    for (var index = 0; index < 6; index++) {
      canvas.drawRect(
        Rect.fromLTWH(rect.left + 8, rect.top + 18 + index * 4, 29, 1.5),
        _fill(_cyan.withValues(alpha: active ? .65 : .2)),
      );
    }
  }

  void _storageBay(
    Canvas canvas,
    Offset center, {
    required double fill,
    required bool locked,
  }) {
    final rect = Rect.fromCenter(center: center, width: 52, height: 58);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      _fill(const Color(0xff11212a)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      _line(_ice.withValues(alpha: .8), 1),
    );
    final slots = (fill * 6).floor().clamp(0, 6);
    for (var index = 0; index < 6; index++) {
      final slot = Rect.fromLTWH(
        rect.left + 9,
        rect.top + 14 + index * 6,
        34,
        3.5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(slot, const Radius.circular(1)),
        _fill(index < slots ? _cyan : const Color(0xff193443)),
      );
    }
    if (locked) {
      canvas.drawLine(
        Offset(rect.left + 5, rect.top + 6),
        Offset(rect.right - 5, rect.top + 6),
        _glow(const Color(0xff8af6e9), 2, 2),
      );
    }
    _center(
      canvas,
      locked ? 'LOCKED' : 'ARCHIVE',
      center + const Offset(0, 23),
      6.5,
      locked ? const Color(0xff8af6e9) : _ice,
    );
  }

  void _receiver(
    Canvas canvas,
    Offset center, {
    required double fill,
    required bool acknowledged,
  }) {
    final rect = Rect.fromCenter(center: center, width: 52, height: 58);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      _fill(const Color(0xff0b1724)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      _line(_cyan.withValues(alpha: acknowledged ? .95 : .55), 1),
    );
    for (var index = 0; index < 8; index++) {
      final x = rect.left + 10 + (index % 4) * 8;
      final y = rect.top + 16 + (index ~/ 4) * 9;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, 5, 5),
          const Radius.circular(1),
        ),
        _fill(index < (fill * 8).floor() ? _ice : const Color(0xff193443)),
      );
    }
    _center(
      canvas,
      acknowledged ? 'ACK' : 'RECEIVER',
      center + const Offset(0, 23),
      6.5,
      acknowledged ? const Color(0xff8af6e9) : _ice,
    );
  }

  void _packet(Canvas canvas, Offset position, {required Color color}) {
    final rect = Rect.fromCenter(center: position, width: 8, height: 3.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
      _glow(color.withValues(alpha: .42), 2, 3.5),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
      _fill(color),
    );
  }

  void _paint3dFaces(
    Canvas canvas,
    SandboxProjection projection,
    List<_RenderFace> faces, {
    required Color border,
  }) {
    final prepared = faces.map((face) {
      final projected = face.vertices.map(projection.project).toList();
      final depth =
          projected.fold(0.0, (sum, item) => sum + item.depth) /
          projected.length;
      return _ProjectedFace(projected, depth, face.normal, face.color);
    }).toList()..sort((a, b) => a.depth.compareTo(b.depth));
    const light = SandboxVec3(-.35, .65, .7);
    for (final face in prepared) {
      final path = Path()
        ..moveTo(face.points.first.offset.dx, face.points.first.offset.dy);
      for (final point in face.points.skip(1)) {
        path.lineTo(point.offset.dx, point.offset.dy);
      }
      path.close();
      final shade = sandboxFaceShade(face.normal, light);
      canvas.drawPath(path, _fill(_scaleColor(face.color, shade)));
      canvas.drawPath(path, _line(border, .65));
    }
  }

  void _text(
    Canvas canvas,
    String value,
    Offset offset,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: 'ShareTechMono',
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _center(
    Canvas canvas,
    String value,
    Offset center,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: 'ShareTechMono',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _right(
    Canvas canvas,
    String value,
    Offset right,
    double size,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: 'ShareTechMono',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(right.dx - painter.width, right.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SendSequencePainter oldDelegate) =>
      oldDelegate.concept != concept ||
      oldDelegate.mode != mode ||
      oldDelegate.operation != operation ||
      oldDelegate.robotAppearance != robotAppearance ||
      oldDelegate.pixelBuilderFinale != pixelBuilderFinale ||
      oldDelegate.progress != progress ||
      oldDelegate.completionElapsedSeconds != completionElapsedSeconds ||
      oldDelegate.reducedMotion != reducedMotion;
}

/// Stable depth partition for the completed-only floating particle field.
enum SandboxParticleDepthLayer { back, side, front }

class SandboxParticleMotionBias {
  const SandboxParticleMotionBias(
    this.minimumVerticalSpeed,
    this.maximumVerticalSpeed,
    this.minimumOscillation,
    this.maximumOscillation,
  );

  final double minimumVerticalSpeed;
  final double maximumVerticalSpeed;
  final double minimumOscillation;
  final double maximumOscillation;
}

/// Configuration accepted by the shared sandbox particle renderer.
class SandboxParticleField {
  const SandboxParticleField({
    required this.center,
    required this.spawnBounds,
    required this.palette,
    required this.density,
    required this.motionBias,
    required this.seed,
    required this.elapsedTime,
    required this.depthLayer,
  });

  final Offset center;
  final Rect spawnBounds;
  final List<Color> palette;
  final int density;
  final SandboxParticleMotionBias motionBias;
  final int seed;
  final double elapsedTime;
  final SandboxParticleDepthLayer depthLayer;

  SandboxParticleField copyWith({
    SandboxParticleDepthLayer? depthLayer,
    double? elapsedTime,
  }) => SandboxParticleField(
    center: center,
    spawnBounds: spawnBounds,
    palette: palette,
    density: density,
    motionBias: motionBias,
    seed: seed,
    elapsedTime: elapsedTime ?? this.elapsedTime,
    depthLayer: depthLayer ?? this.depthLayer,
  );
}

class SandboxParticleVisual {
  const SandboxParticleVisual({
    required this.index,
    required this.position,
    required this.radius,
    required this.color,
    required this.coreAlpha,
    required this.nearAlpha,
    required this.wideAlpha,
    required this.depthLayer,
  });

  final int index;
  final Offset position;
  final double radius;
  final Color color;
  final double coreAlpha;
  final double nearAlpha;
  final double wideAlpha;
  final SandboxParticleDepthLayer depthLayer;
}

int sandboxParticleCount(BootSendSequenceConcept concept) => switch (concept) {
  BootSendSequenceConcept.assemblyMatrix => 12,
  BootSendSequenceConcept.voxelIntegration => 18,
  BootSendSequenceConcept.polyhedralFold => 15,
  BootSendSequenceConcept.messageAssembly => 0,
};

/// Pure deterministic particle positions.  It deliberately does not use
/// Random so replaying a concept produces the same floating energy field.
List<SandboxParticleVisual> sandboxParticleVisuals(
  SandboxParticleField field, {
  bool reducedMotion = false,
}) {
  final count = reducedMotion ? 4 : field.density;
  final visuals = <SandboxParticleVisual>[];
  final backCount = (count * .35).round();
  final sideCount = (count * .45).round();
  for (var index = 0; index < count; index++) {
    final layer = index < backCount
        ? SandboxParticleDepthLayer.back
        : index < backCount + sideCount
        ? SandboxParticleDepthLayer.side
        : SandboxParticleDepthLayer.front;
    if (layer != field.depthLayer) continue;
    final sector = index % 4;
    final horizontal = _particleUnit(field.seed, index, 1);
    final vertical = _particleUnit(field.seed, index, 2);
    final inset = _particleUnit(field.seed, index, 3);
    final origin = switch (sector) {
      0 => Offset(
        field.spawnBounds.left + 3 + inset * 7,
        field.spawnBounds.top +
            field.spawnBounds.height * (.12 + vertical * .76),
      ),
      1 => Offset(
        field.spawnBounds.right - 3 - inset * 7,
        field.spawnBounds.top +
            field.spawnBounds.height * (.12 + vertical * .76),
      ),
      2 => Offset(
        field.spawnBounds.left +
            field.spawnBounds.width * (.12 + horizontal * .76),
        field.spawnBounds.bottom - 3 - inset * 5,
      ),
      _ => Offset(
        field.spawnBounds.left +
            field.spawnBounds.width * (.12 + horizontal * .76),
        field.spawnBounds.top + 3 + inset * 5,
      ),
    };
    final phaseOffset = _particleUnit(field.seed, index, 4);
    final palettePick = (_particleUnit(field.seed, index, 5) * 20).floor();
    final color =
        field.palette[palettePick < 9
            ? 0
            : palettePick < 15
            ? 1
            : palettePick < 18
            ? 2
            : 3];
    if (reducedMotion) {
      visuals.add(
        SandboxParticleVisual(
          index: index,
          position: origin,
          radius: 1.4 + (index % 3) * .35,
          color: field.palette[index.isEven ? 1 : 3],
          coreAlpha: .35,
          nearAlpha: .12,
          wideAlpha: .08,
          depthLayer: layer,
        ),
      );
      continue;
    }
    final lifespan = 1.4 + _particleUnit(field.seed, index, 6) * 1.2;
    final life = (field.elapsedTime / lifespan + phaseOffset).remainder(1.0);
    final velocity =
        field.motionBias.minimumVerticalSpeed +
        _particleUnit(field.seed, index, 7) *
            (field.motionBias.maximumVerticalSpeed -
                field.motionBias.minimumVerticalSpeed);
    final oscillation =
        field.motionBias.minimumOscillation +
        _particleUnit(field.seed, index, 8) *
            (field.motionBias.maximumOscillation -
                field.motionBias.minimumOscillation);
    final period = 2 + _particleUnit(field.seed, index, 9) * 1.4;
    final position = Offset(
      origin.dx +
          oscillation *
              math.sin(
                2 * math.pi * field.elapsedTime / period +
                    phaseOffset * 2 * math.pi,
              ),
      origin.dy - velocity * lifespan * life,
    );
    final envelope = _particleEnvelope(life);
    final fadeIn = _smoothStep(0, .35, field.elapsedTime);
    final front = layer == SandboxParticleDepthLayer.front ? .75 : 1.0;
    final corePeak = .55 + _particleUnit(field.seed, index, 10) * .35;
    final glowPeak = .18 + _particleUnit(field.seed, index, 11) * .14;
    final alpha = envelope * fadeIn * front;
    visuals.add(
      SandboxParticleVisual(
        index: index,
        position: position,
        radius: _particleRadius(index),
        color: color,
        coreAlpha: corePeak * alpha,
        nearAlpha: glowPeak * alpha,
        wideAlpha: glowPeak * .72 * alpha,
        depthLayer: layer,
      ),
    );
  }
  return visuals;
}

double _particleUnit(int seed, int index, int salt) {
  final value =
      math.sin(
        (seed * 73856093 + index * 19349663 + salt * 83492791).toDouble(),
      ) *
      43758.5453123;
  return value - value.floorToDouble();
}

double _particleRadius(int index) {
  final bucket = index % 10;
  if (bucket < 6) return 1.4;
  if (bucket < 9) return 2.1;
  return 2.8;
}

double _particleEnvelope(double phase) =>
    _smoothStep(0, .15, phase) * (1 - _smoothStep(.7, 1, phase));

double _smoothStep(double edge0, double edge1, double value) {
  final normalized = ((value - edge0) / (edge1 - edge0)).clamp(0, 1).toDouble();
  return normalized * normalized * (3 - 2 * normalized);
}

/// Small immutable 3D vector used only by the sandbox renderers and tests.
class SandboxVec3 {
  const SandboxVec3(this.x, this.y, this.z);

  static const zero = SandboxVec3(0, 0, 0);
  final double x;
  final double y;
  final double z;

  SandboxVec3 operator +(SandboxVec3 other) =>
      SandboxVec3(x + other.x, y + other.y, z + other.z);
  SandboxVec3 operator -(SandboxVec3 other) =>
      SandboxVec3(x - other.x, y - other.y, z - other.z);
  SandboxVec3 operator *(double scalar) =>
      SandboxVec3(x * scalar, y * scalar, z * scalar);
  double dot(SandboxVec3 other) => x * other.x + y * other.y + z * other.z;
  SandboxVec3 cross(SandboxVec3 other) => SandboxVec3(
    y * other.z - z * other.y,
    z * other.x - x * other.z,
    x * other.y - y * other.x,
  );
  double get length => math.sqrt(dot(this));
  SandboxVec3 normalized() {
    final magnitude = length;
    return magnitude == 0 ? zero : this * (1 / magnitude);
  }

  SandboxVec3 rotateX(double radians) => SandboxVec3(
    x,
    y * math.cos(radians) - z * math.sin(radians),
    y * math.sin(radians) + z * math.cos(radians),
  );
  SandboxVec3 rotateY(double radians) => SandboxVec3(
    x * math.cos(radians) + z * math.sin(radians),
    y,
    -x * math.sin(radians) + z * math.cos(radians),
  );

  /// Rodrigues rotation about a normalized physical hinge axis.
  SandboxVec3 rotateAroundAxis(
    SandboxVec3 pivot,
    SandboxVec3 axis,
    double radians,
  ) {
    final normalizedAxis = axis.normalized();
    final vector = this - pivot;
    final cosine = math.cos(radians);
    final sine = math.sin(radians);
    final rotated =
        vector * cosine +
        normalizedAxis.cross(vector) * sine +
        normalizedAxis * (normalizedAxis.dot(vector) * (1 - cosine));
    return pivot + rotated;
  }

  static SandboxVec3 lerp(SandboxVec3 a, SandboxVec3 b, double t) =>
      a + (b - a) * t;
}

class SandboxProjection {
  const SandboxProjection(this.center);

  final Offset center;
  static const _cameraDistance = 400.0;
  static const _focalLength = 310.0;
  static const _yaw = -30 * math.pi / 180;
  static const _pitch = 22 * math.pi / 180;

  SandboxProjectedPoint project(SandboxVec3 point) {
    final viewed = point.rotateY(_yaw).rotateX(_pitch);
    final denominator = math.max(24.0, _cameraDistance - viewed.z);
    final scale = _focalLength / denominator;
    return SandboxProjectedPoint(
      Offset(center.dx + viewed.x * scale, center.dy - viewed.y * scale),
      viewed.z,
    );
  }
}

/// MESSAGE ASSEMBLY owns a cinematic camera without changing the projection
/// contract used by the accepted Matrix, Voxel, and Polyhedral scenes.
class _MessageProjection extends SandboxProjection {
  const _MessageProjection(this.elapsed) : super(const Offset(180, 140));

  final double elapsed;

  @override
  SandboxProjectedPoint project(SandboxVec3 point) {
    final pullBack = _smoothStep(3000, 4700, elapsed);
    final multiplier = 1.85 + (1 - 1.85) * pullBack;
    final yaw = (-25 + 25 * pullBack) * math.pi / 180;
    final pitch = (18 - 18 * pullBack) * math.pi / 180;
    final viewed = point.rotateY(yaw).rotateX(pitch);
    final denominator = math.max(24.0, 400 - viewed.z);
    final scale = 310 / denominator * multiplier;
    return SandboxProjectedPoint(
      Offset(180 + viewed.x * scale, 140 - viewed.y * scale),
      viewed.z,
    );
  }
}

class SandboxProjectedPoint {
  const SandboxProjectedPoint(this.offset, this.depth);
  final Offset offset;
  final double depth;
}

class SandboxFace {
  const SandboxFace(this.vertices, this.normal);
  final List<SandboxVec3> vertices;
  final SandboxVec3 normal;

  SandboxFace transform(SandboxVec3 Function(SandboxVec3 point) transform) =>
      SandboxFace(vertices.map(transform).toList(growable: false), normal);
}

class _RenderFace {
  const _RenderFace(this.vertices, this.normal, this.color);
  final List<SandboxVec3> vertices;
  final SandboxVec3 normal;
  final Color color;
}

class _ProjectedFace {
  const _ProjectedFace(this.points, this.depth, this.normal, this.color);
  final List<SandboxProjectedPoint> points;
  final double depth;
  final SandboxVec3 normal;
  final Color color;
}

List<int> sandboxMatrixAssemblyOrder() {
  final cells = List<int>.generate(36, (index) => index);
  cells.sort((a, b) {
    final ar = a ~/ 6;
    final ac = a % 6;
    final br = b ~/ 6;
    final bc = b % 6;
    final ad = math.max((ar - 2.5).abs(), (ac - 2.5).abs());
    final bd = math.max((br - 2.5).abs(), (bc - 2.5).abs());
    final distance = ad.compareTo(bd);
    if (distance != 0) return distance;
    final row = ar.compareTo(br);
    return row != 0 ? row : ac.compareTo(bc);
  });
  return cells;
}

List<SandboxVec3> sandboxMatrixModuleCenters() => [
  for (var row = 0; row < 6; row++)
    for (var column = 0; column < 6; column++)
      SandboxVec3((column - 2.5) * 16, (2.5 - row) * 16, 0),
];

List<(int, int)> sandboxMatrixAdjacencyLinks() => [
  for (var row = 0; row < 6; row++)
    for (var column = 0; column < 5; column++)
      (row * 6 + column, row * 6 + column + 1),
  for (var row = 0; row < 5; row++)
    for (var column = 0; column < 6; column++)
      (row * 6 + column, (row + 1) * 6 + column),
];

List<SandboxVec3> sandboxVoxelCenters() => [
  for (final z in [-24.0, 0.0, 24.0])
    for (final y in [-24.0, 0.0, 24.0])
      for (final x in [-24.0, 0.0, 24.0]) SandboxVec3(x, y, z),
];

SandboxVec3 sandboxVoxelSource(int index) {
  const goldenAngle = 2.399963229728653;
  final u = (index + .5) / 27;
  final z = 2 * u - 1;
  final radius = math.sqrt(1 - z * z);
  final theta = index * goldenAngle;
  return SandboxVec3(
    120 * radius * math.cos(theta),
    120 * radius * math.sin(theta),
    120 * z,
  );
}

Color sandboxVoxelColor(SandboxVec3 center) {
  final base = switch (center.z) {
    < 0 => const Color(0xff5fa8ff),
    > 0 => const Color(0xff7b90ff),
    _ => const Color(0xff63d8ff),
  };
  final blended = Color.lerp(base, const Color(0xff63d8ff), .35)!;
  final distance =
      (center.x.abs() / 24 + center.y.abs() / 24 + center.z.abs() / 24).round();
  final brightness = distance == 0
      ? 1.12
      : distance < 3
      ? 1.06
      : 1.0;
  return _scaleColor(blended, brightness);
}

Color sandboxVoxelColorForIndex(SandboxVec3 center, int index) {
  final variation = ((index * 7) % 9 - 4) / 100;
  return _scaleColor(sandboxVoxelColor(center), 1 + variation);
}

Color _scaleColor(Color color, double factor) => Color.from(
  alpha: color.a,
  red: (color.r * factor).clamp(0, 1),
  green: (color.g * factor).clamp(0, 1),
  blue: (color.b * factor).clamp(0, 1),
);

double sandboxFaceShade(SandboxVec3 normal, SandboxVec3 light) {
  final diffuse = math.max(0, normal.normalized().dot(light.normalized()));
  return .45 + .55 * diffuse;
}

List<SandboxFace> sandboxRectangularPrismFaces(
  SandboxVec3 center,
  double width,
  double height,
  double depth,
) {
  final halfX = width / 2;
  final halfY = height / 2;
  final halfZ = depth / 2;
  final vertices = [
    SandboxVec3(center.x - halfX, center.y - halfY, center.z - halfZ),
    SandboxVec3(center.x + halfX, center.y - halfY, center.z - halfZ),
    SandboxVec3(center.x + halfX, center.y + halfY, center.z - halfZ),
    SandboxVec3(center.x - halfX, center.y + halfY, center.z - halfZ),
    SandboxVec3(center.x - halfX, center.y - halfY, center.z + halfZ),
    SandboxVec3(center.x + halfX, center.y - halfY, center.z + halfZ),
    SandboxVec3(center.x + halfX, center.y + halfY, center.z + halfZ),
    SandboxVec3(center.x - halfX, center.y + halfY, center.z + halfZ),
  ];
  SandboxFace face(List<int> points, SandboxVec3 normal) =>
      SandboxFace(points.map((index) => vertices[index]).toList(), normal);
  return [
    face([4, 5, 6, 7], const SandboxVec3(0, 0, 1)),
    face([1, 0, 3, 2], const SandboxVec3(0, 0, -1)),
    face([1, 2, 6, 5], const SandboxVec3(1, 0, 0)),
    face([0, 4, 7, 3], const SandboxVec3(-1, 0, 0)),
    face([3, 7, 6, 2], const SandboxVec3(0, 1, 0)),
    face([0, 1, 5, 4], const SandboxVec3(0, -1, 0)),
  ];
}

List<SandboxFace> sandboxCubeFaces(SandboxVec3 center, double side) {
  final half = side / 2;
  final vertices = [
    SandboxVec3(center.x - half, center.y - half, center.z - half),
    SandboxVec3(center.x + half, center.y - half, center.z - half),
    SandboxVec3(center.x + half, center.y + half, center.z - half),
    SandboxVec3(center.x - half, center.y + half, center.z - half),
    SandboxVec3(center.x - half, center.y - half, center.z + half),
    SandboxVec3(center.x + half, center.y - half, center.z + half),
    SandboxVec3(center.x + half, center.y + half, center.z + half),
    SandboxVec3(center.x - half, center.y + half, center.z + half),
  ];
  SandboxFace face(List<int> indices, SandboxVec3 normal) =>
      SandboxFace(indices.map((index) => vertices[index]).toList(), normal);
  return [
    face([4, 5, 6, 7], const SandboxVec3(0, 0, 1)),
    face([1, 0, 3, 2], const SandboxVec3(0, 0, -1)),
    face([1, 2, 6, 5], const SandboxVec3(1, 0, 0)),
    face([0, 4, 7, 3], const SandboxVec3(-1, 0, 0)),
    face([3, 7, 6, 2], const SandboxVec3(0, 1, 0)),
    face([0, 1, 5, 4], const SandboxVec3(0, -1, 0)),
  ];
}

List<SandboxFace> sandboxFinalCubeFaces() =>
    sandboxCubeFaces(SandboxVec3.zero, 80);

List<SandboxFace> sandboxFusionCubeFaces(double progress) {
  final targets = sandboxFinalCubeFaces();
  final order = [5, 0, 3, 2, 1, 4];
  final orderIndex = {for (var i = 0; i < order.length; i++) order[i]: i};
  const offsets = [
    SandboxVec3(12, -12, 0),
    SandboxVec3(-10, 14, 0),
    SandboxVec3(0, 15, 10),
    SandboxVec3(0, -12, -14),
    SandboxVec3(16, 0, 8),
    SandboxVec3(-14, 0, -10),
  ];
  return [
    for (var index = 0; index < targets.length; index++)
      _fusionFace(
        targets[index],
        offsets[index],
        _ease(
          _phase(
            progress,
            orderIndex[index]! * .08,
            .6 + orderIndex[index]! * .08,
          ),
        ),
      ),
  ];
}

SandboxFace _fusionFace(SandboxFace target, SandboxVec3 tangent, double t) {
  final center = target.vertices.reduce((a, b) => a + b) * .25;
  final sourceCenter = center + target.normal * 65 + tangent;
  final axis = target.normal.z.abs() > .5
      ? const SandboxVec3(0, 1, 0)
      : const SandboxVec3(1, 0, 0);
  final initialAngle = 15 * math.pi / 180;
  final currentCenter = SandboxVec3.lerp(sourceCenter, center, t);
  return SandboxFace(
    target.vertices.map((vertex) {
      final sourceOffset = (vertex - center).rotateAroundAxis(
        SandboxVec3.zero,
        axis,
        initialAngle,
      );
      return currentCenter +
          sourceOffset.rotateAroundAxis(
            SandboxVec3.zero,
            axis,
            -initialAngle * t,
          );
    }).toList(),
    target.normal.rotateAroundAxis(
      SandboxVec3.zero,
      axis,
      initialAngle * (1 - t),
    ),
  );
}

List<(SandboxVec3, SandboxVec3)> sandboxCubeEdges() {
  final edges = <String, (SandboxVec3, SandboxVec3)>{};
  for (final face in sandboxFinalCubeFaces()) {
    for (var index = 0; index < 4; index++) {
      final a = face.vertices[index];
      final b = face.vertices[(index + 1) % 4];
      final key = [
        a,
        b,
      ].map((point) => '${point.x}:${point.y}:${point.z}').toList()..sort();
      edges[key.join('|')] = (a, b);
    }
  }
  return edges.values.toList();
}

List<SandboxFace> sandboxFoldedCubeFaces(double progress) {
  const side = 80.0;
  const h = 40.0;
  final base = sandboxCubeFaces(SandboxVec3.zero, side).first;
  final rightProgress = _hingeProgress(progress, 0, .56);
  final leftProgress = _hingeProgress(progress, .10, .66);
  final topProgress = _hingeProgress(progress, .20, .76);
  final bottomProgress = _hingeProgress(progress, .30, .86);
  final rearProgress = _hingeProgress(progress, .46, 1);
  SandboxFace make(List<SandboxVec3> points, SandboxVec3 normal) =>
      SandboxFace(points, normal);
  final right = make([
    const SandboxVec3(h, -h, h),
    const SandboxVec3(3 * h, -h, h),
    const SandboxVec3(3 * h, h, h),
    const SandboxVec3(h, h, h),
  ], const SandboxVec3(0, 0, 1));
  final left = make([
    const SandboxVec3(-3 * h, -h, h),
    const SandboxVec3(-h, -h, h),
    const SandboxVec3(-h, h, h),
    const SandboxVec3(-3 * h, h, h),
  ], const SandboxVec3(0, 0, 1));
  final top = make([
    const SandboxVec3(-h, h, h),
    const SandboxVec3(h, h, h),
    const SandboxVec3(h, 3 * h, h),
    const SandboxVec3(-h, 3 * h, h),
  ], const SandboxVec3(0, 0, 1));
  final bottom = make([
    const SandboxVec3(-h, -3 * h, h),
    const SandboxVec3(h, -3 * h, h),
    const SandboxVec3(h, -h, h),
    const SandboxVec3(-h, -h, h),
  ], const SandboxVec3(0, 0, 1));
  final rear = make([
    const SandboxVec3(-h, 3 * h, h),
    const SandboxVec3(h, 3 * h, h),
    const SandboxVec3(h, 5 * h, h),
    const SandboxVec3(-h, 5 * h, h),
  ], const SandboxVec3(0, 0, 1));
  SandboxFace rotateFace(
    SandboxFace face,
    SandboxVec3 pivot,
    SandboxVec3 axis,
    double angle,
  ) => SandboxFace(
    face.vertices
        .map((point) => point.rotateAroundAxis(pivot, axis, angle))
        .toList(),
    face.normal.rotateAroundAxis(SandboxVec3.zero, axis, angle),
  );
  final foldedRight = rotateFace(
    right,
    const SandboxVec3(h, 0, h),
    const SandboxVec3(0, 1, 0),
    math.pi / 2 * rightProgress,
  );
  final foldedLeft = rotateFace(
    left,
    const SandboxVec3(-h, 0, h),
    const SandboxVec3(0, 1, 0),
    -math.pi / 2 * leftProgress,
  );
  final foldedTop = rotateFace(
    top,
    const SandboxVec3(0, h, h),
    const SandboxVec3(1, 0, 0),
    -math.pi / 2 * topProgress,
  );
  final foldedBottom = rotateFace(
    bottom,
    const SandboxVec3(0, -h, h),
    const SandboxVec3(1, 0, 0),
    math.pi / 2 * bottomProgress,
  );
  final topPivot = const SandboxVec3(0, h, h);
  final parentAngle = -math.pi / 2 * topProgress;
  final rearAfterParent = rotateFace(
    rear,
    topPivot,
    const SandboxVec3(1, 0, 0),
    parentAngle,
  );
  final rearHinge = const SandboxVec3(
    0,
    3 * h,
    h,
  ).rotateAroundAxis(topPivot, const SandboxVec3(1, 0, 0), parentAngle);
  final rearAxis = const SandboxVec3(
    1,
    0,
    0,
  ).rotateAroundAxis(SandboxVec3.zero, const SandboxVec3(1, 0, 0), parentAngle);
  final foldedRear = rotateFace(
    rearAfterParent,
    rearHinge,
    rearAxis,
    -math.pi / 2 * rearProgress,
  );
  return [base, foldedRight, foldedLeft, foldedTop, foldedBottom, foldedRear];
}

double _hingeProgress(double progress, double start, double end) =>
    Curves.easeInOutCubic.transform(_phase(progress, start, end));
