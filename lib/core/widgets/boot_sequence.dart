import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/boot_audio.dart';
import '../services/operation_system_metadata.dart';
import '../services/startup_diagnostic.dart';
import '../state/app_initialization_state.dart';

enum BootSequenceEventType { bootStart, systemInitialized, bootComplete }

class BootSequenceEvent {
  final BootSequenceEventType type;
  final DateTime occurredAt;

  const BootSequenceEvent({required this.type, required this.occurredAt});
}

typedef BootSequenceEventListener = void Function(BootSequenceEvent event);

const _fullName = 'Operation Reasoning Lifesystem Orchestrator';
const _bootSignalHandoffDuration = Duration(milliseconds: 120);

/// Applies only after the logo Fade. These base durations are deliberately
/// chosen as a timeline, rather than derived from another global multiplier:
/// the deterministic Boot visible → Main UI path is about 4.49 seconds.
const postLogoBootTimingFactor = 1.0;
const bootSignalCoreColor = Color(0xFFF4FAFC);
const bootSignalHaloColor = Color(0x707FADBA);
const bootSignalFragmentColor = Color(0xB8A4C4CE);
const bootBackgroundColor = Color(0xFF101010);
const _bootTerminalFontFamily = 'ShareTechMono';

/// The acquisition renderer is deliberately selectable at one point so a
/// real-device rollback never requires reconstructing a prior visual model.
/// Production uses [microSignalField]; [legacyInterference] retains the
/// pre-pivot 1b589b9 renderer unchanged.
enum BootSignalMode { legacyInterference, microSignalField }

/// The fixed count deliberately reads as mixed signal detail rather than a
/// uniformly spaced scan pattern. The segments are positioned and timed with
/// deterministic envelopes in [_BootLegacySignalAcquisitionPainter].
@visibleForTesting
const bootSignalAcquisitionFineSegmentCount = 18;
const _bootSignalAcquisitionLockFragmentCount = 4;
const _legacySignalAcquisitionDuration = Duration(milliseconds: 300);
const _microSignalAcquisitionDuration = Duration(milliseconds: 500);

/// A bounded field of deterministic source primitives. Offset pairs render a
/// second related fragment, but still count as one signal primitive here.
@visibleForTesting
const bootMicroSignalFieldPrimitiveCount = 64;

enum _BootMicroSignalPrimitiveType {
  horizontalFragment,
  microBlock,
  signalSpeck,
  offsetPair,
  darkInterruption,
}

@immutable
class _BootMicroSignalSeed {
  const _BootMicroSignalSeed({
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.onset,
    required this.lifetime,
    required this.phase,
    required this.frequency,
  });

  final _BootMicroSignalPrimitiveType type;
  final double x;
  final double y;
  final double width;
  final double height;
  final double onset;
  final double lifetime;
  final double phase;
  final double frequency;
}

/// The source field is deterministic, but never quantized into columns or
/// rows. It is built once per process, so rendering only reads bounded seeds.
final List<_BootMicroSignalSeed> _bootMicroSignalSeeds =
    _buildBootMicroSignalSeeds();

double _bootNoiseUnit(int index, int salt, [int attempt = 0]) {
  var value = index * 0x45d9f3b ^ salt * 0x27d4eb2d ^ attempt * 0x165667b1;
  value = (value ^ (value >> 16)) * 0x45d9f3b;
  value = (value ^ (value >> 16)) * 0x45d9f3b;
  value ^= value >> 16;
  return (value & 0x7fffffff) / 0x7fffffff;
}

bool _bootSeedCreatesLane(
  List<_BootMicroSignalSeed> seeds,
  double x,
  double y,
) {
  var nearColumnCount = 0;
  var nearRowCount = 0;
  for (final seed in seeds) {
    // Leave enough separation for the bounded render-time jitter as well as
    // the fragment itself. This prevents a visually straight lane from being
    // reintroduced after the continuous coordinates are animated.
    if ((seed.x - x).abs() < .055 && (seed.y - y).abs() > .040) {
      nearColumnCount += 1;
    }
    if ((seed.y - y).abs() < .046 && (seed.x - x).abs() > .045) {
      nearRowCount += 1;
    }
  }
  return nearColumnCount >= 1 || nearRowCount >= 1;
}

List<_BootMicroSignalSeed> _buildBootMicroSignalSeeds() {
  final seeds = <_BootMicroSignalSeed>[];
  for (var index = 0; index < bootMicroSignalFieldPrimitiveCount; index += 1) {
    var attempt = 0;
    var x = .025 + _bootNoiseUnit(index, 11) * .94;
    var y = .09 + _bootNoiseUnit(index, 29) * .82;
    while (_bootSeedCreatesLane(seeds, x, y) && attempt < 128) {
      attempt += 1;
      x = .025 + _bootNoiseUnit(index, 11, attempt) * .94;
      y = .09 + _bootNoiseUnit(index, 29, attempt) * .82;
    }
    final typeIndex =
        (_bootNoiseUnit(index, 43, attempt) *
                _BootMicroSignalPrimitiveType.values.length)
            .floor();
    seeds.add(
      _BootMicroSignalSeed(
        type: _BootMicroSignalPrimitiveType.values[typeIndex],
        x: x,
        y: y,
        width: _bootNoiseUnit(index, 61, attempt),
        height: _bootNoiseUnit(index, 79, attempt),
        onset: .02 + _bootNoiseUnit(index, 97, attempt) * .34,
        lifetime: .24 + _bootNoiseUnit(index, 113, attempt) * .30,
        phase: _bootNoiseUnit(index, 131, attempt) * math.pi * 2,
        frequency: 17 + _bootNoiseUnit(index, 149, attempt) * 31,
      ),
    );
  }
  return List.unmodifiable(seeds);
}

@immutable
class BootSignalAcquisitionDiagnostics {
  const BootSignalAcquisitionDiagnostics({
    required this.elapsed,
    required this.activeFineFragmentCount,
    required this.activeLockFragmentCount,
    required this.minimumEffectiveOpacity,
    required this.maximumEffectiveOpacity,
    required this.minimumStrokeWidth,
    required this.maximumStrokeWidth,
    required this.minimumLogicalWidth,
    required this.maximumLogicalWidth,
    required this.aggregateHorizontalCoverage,
    required this.minimumVerticalFraction,
    required this.maximumVerticalFraction,
    required this.parentOpacityMultiplier,
    required this.hasAdditionalClip,
  });

  final Duration elapsed;
  final int activeFineFragmentCount;
  final int activeLockFragmentCount;
  final double minimumEffectiveOpacity;
  final double maximumEffectiveOpacity;
  final double minimumStrokeWidth;
  final double maximumStrokeWidth;
  final double minimumLogicalWidth;
  final double maximumLogicalWidth;

  /// Sum of active fragment widths divided by viewport width. It is a bounded
  /// scale diagnostic, not a visual-quality or non-overlap measurement.
  final double aggregateHorizontalCoverage;
  final double minimumVerticalFraction;
  final double maximumVerticalFraction;
  final double parentOpacityMultiplier;
  final bool hasAdditionalClip;
}

@immutable
class BootMicroSignalFieldDiagnostics {
  const BootMicroSignalFieldDiagnostics({
    required this.elapsed,
    required this.activePrimitiveCount,
    required this.activeCountByType,
    required this.minimumEffectiveOpacity,
    required this.maximumEffectiveOpacity,
    required this.minimumLogicalWidth,
    required this.maximumLogicalWidth,
    required this.minimumLogicalHeight,
    required this.maximumLogicalHeight,
    required this.aggregateHorizontalCoverage,
    required this.minimumVerticalFraction,
    required this.maximumVerticalFraction,
    required this.maximumNearColumnRun,
    required this.maximumNearRowRun,
  });

  final Duration elapsed;
  final int activePrimitiveCount;
  final Map<String, int> activeCountByType;
  final double minimumEffectiveOpacity;
  final double maximumEffectiveOpacity;
  final double minimumLogicalWidth;
  final double maximumLogicalWidth;
  final double minimumLogicalHeight;
  final double maximumLogicalHeight;
  final double aggregateHorizontalCoverage;
  final double minimumVerticalFraction;
  final double maximumVerticalFraction;
  final int maximumNearColumnRun;
  final int maximumNearRowRun;
}

@visibleForTesting
double bootSignalAcquisitionLineOpacity(double progress) {
  final detection = Curves.easeOut.transform((progress / .24).clamp(0.0, 1.0));
  final lock = Curves.easeInOut.transform(
    ((progress - .70) / .30).clamp(0.0, 1.0),
  );
  return .08 * detection + .72 * lock;
}

@visibleForTesting
double bootSignalAcquisitionInterferenceOpacity(double progress) =>
    math.sin(((progress - .14) / .70).clamp(0.0, 1.0).toDouble() * math.pi);

/// The dense mixed-signal window runs from roughly 135ms through 225ms of
/// the fixed 300ms acquisition. It stays visible across several real-device
/// frames, then decays into the lock line rather than cutting to black.
@visibleForTesting
double bootSignalAcquisitionDensity(double progress) {
  final build = Curves.easeOut.transform(
    ((progress - .12) / .33).clamp(0.0, 1.0),
  );
  final converge =
      1 - Curves.easeIn.transform(((progress - .74) / .20).clamp(0.0, 1.0));
  return build * converge;
}

double _bootSignalFineFragmentOnset(int index) => .03 + (index % 6) * .055;

double _bootSignalFineFragmentEnd(int index) => .80 - (index % 4) * .035;

double _bootSignalFineFragmentOpacity(double progress, int index) {
  final local =
      ((progress - _bootSignalFineFragmentOnset(index)) /
              (_bootSignalFineFragmentEnd(index) -
                  _bootSignalFineFragmentOnset(index)))
          .clamp(0.0, 1.0)
          .toDouble();
  return bootSignalAcquisitionInterferenceOpacity(progress) *
      bootSignalAcquisitionDensity(progress) *
      math.sin(local * math.pi) *
      (.23 + (index % 4) * .055);
}

double _bootSignalFineFragmentWidth(Size size, int index) =>
    size.width * (.035 + (index % 6) * .016);

double _bootSignalFineFragmentY(Size size, double progress, int index) {
  final distribution = .14 + ((index * .173) % .72);
  return size.height * distribution +
      ((index * 19) % 31 - 15) +
      math.sin(progress * 41 + index) * 2.4;
}

double _bootSignalFineFragmentStart(Size size, double progress, int index) {
  final offset =
      math.sin(progress * (16 + index * 2.7) + index * .9) *
      (5 + (index % 5) * 1.8);
  return (size.width * (.035 + ((index * .137) % .76)) + offset)
      .clamp(0.0, size.width)
      .toDouble();
}

double _bootSignalFineFragmentStrokeWidth(int index) =>
    index % 5 == 0 ? 1.55 : 1.0;

double _bootSignalLockFragmentOpacity(double progress) =>
    bootSignalAcquisitionInterferenceOpacity(progress) *
    bootSignalAcquisitionDensity(progress) *
    .24;

double _bootSignalLockFragmentWidth(Size size, int index) =>
    size.width * (.10 + index * .018);

double _bootSignalLockFragmentY(
  Size size,
  double centerY,
  double lineJitter,
  int index,
) {
  final direction = index.isEven ? 1.0 : -1.0;
  return centerY + direction * (18 + index * 17) + lineJitter;
}

double _bootSignalLockFragmentStart(Size size, double progress, int index) {
  final offset = math.sin(progress * (18 + index * 6) + index) * 15;
  return (size.width * (.16 + index * .17) + offset)
      .clamp(0.0, size.width)
      .toDouble();
}

/// Test-only rendering metrics for the same deterministic geometry used by
/// the acquisition painter. This does not run in the production animation.
@visibleForTesting
BootSignalAcquisitionDiagnostics bootSignalAcquisitionDiagnosticsAt(
  Duration elapsed,
  Size size,
) {
  final progress =
      (elapsed.inMicroseconds / _legacySignalAcquisitionDuration.inMicroseconds)
          .clamp(0.0, 1.0)
          .toDouble();
  final centerY = size.height / 2;
  final lineJitter = math.sin(progress * 49) * (1.8 - progress * .8);
  final lineOpacity = bootSignalAcquisitionLineOpacity(progress);
  final detection = Curves.easeOut.transform((progress / .24).clamp(0.0, 1.0));
  final lineWidth = size.width * (.18 + .64 * detection);
  final lineThickness = 1.2 + 1.1 * math.sin(progress * 37).abs();
  var activeFineFragmentCount = 0;
  var activeLockFragmentCount = 0;
  var minimumOpacity = lineOpacity;
  var maximumOpacity = lineOpacity;
  var minimumStrokeWidth = lineThickness;
  var maximumStrokeWidth = lineThickness;
  var minimumLogicalWidth = lineWidth;
  var maximumLogicalWidth = lineWidth;
  var minimumY = centerY + lineJitter;
  var maximumY = centerY + lineJitter;
  var aggregateWidth = 0.0;

  for (
    var index = 0;
    index < bootSignalAcquisitionFineSegmentCount;
    index += 1
  ) {
    final opacity = _bootSignalFineFragmentOpacity(progress, index);
    if (opacity <= .01) continue;
    final y = _bootSignalFineFragmentY(size, progress, index);
    final width = _bootSignalFineFragmentWidth(size, index);
    final strokeWidth = _bootSignalFineFragmentStrokeWidth(index);
    activeFineFragmentCount += 1;
    minimumOpacity = math.min(minimumOpacity, opacity);
    maximumOpacity = math.max(maximumOpacity, opacity);
    minimumStrokeWidth = math.min(minimumStrokeWidth, strokeWidth);
    maximumStrokeWidth = math.max(maximumStrokeWidth, strokeWidth);
    minimumLogicalWidth = math.min(minimumLogicalWidth, width);
    maximumLogicalWidth = math.max(maximumLogicalWidth, width);
    minimumY = math.min(minimumY, y);
    maximumY = math.max(maximumY, y + strokeWidth);
    aggregateWidth += width;
  }
  for (
    var index = 0;
    index < _bootSignalAcquisitionLockFragmentCount;
    index += 1
  ) {
    final opacity = _bootSignalLockFragmentOpacity(progress);
    if (opacity <= .01) continue;
    final y = _bootSignalLockFragmentY(size, centerY, lineJitter, index);
    final width = _bootSignalLockFragmentWidth(size, index);
    activeLockFragmentCount += 1;
    minimumOpacity = math.min(minimumOpacity, opacity);
    maximumOpacity = math.max(maximumOpacity, opacity);
    minimumStrokeWidth = math.min(minimumStrokeWidth, 1.1);
    maximumStrokeWidth = math.max(maximumStrokeWidth, 1.1);
    minimumLogicalWidth = math.min(minimumLogicalWidth, width);
    maximumLogicalWidth = math.max(maximumLogicalWidth, width);
    minimumY = math.min(minimumY, y);
    maximumY = math.max(maximumY, y + 1.1);
    aggregateWidth += width;
  }

  return BootSignalAcquisitionDiagnostics(
    elapsed: elapsed,
    activeFineFragmentCount: activeFineFragmentCount,
    activeLockFragmentCount: activeLockFragmentCount,
    minimumEffectiveOpacity: minimumOpacity,
    maximumEffectiveOpacity: maximumOpacity,
    minimumStrokeWidth: minimumStrokeWidth,
    maximumStrokeWidth: maximumStrokeWidth,
    minimumLogicalWidth: minimumLogicalWidth,
    maximumLogicalWidth: maximumLogicalWidth,
    aggregateHorizontalCoverage: aggregateWidth / size.width,
    minimumVerticalFraction: minimumY / size.height,
    maximumVerticalFraction: maximumY / size.height,
    parentOpacityMultiplier: 1,
    hasAdditionalClip: false,
  );
}

_BootMicroSignalSeed _bootMicroSignalSeed(int index) =>
    _bootMicroSignalSeeds[index];

_BootMicroSignalPrimitiveType _bootMicroSignalType(int index) =>
    _bootMicroSignalSeed(index).type;

double _bootMicroSignalOnset(int index) => _bootMicroSignalSeed(index).onset;

double _bootMicroSignalEnd(int index) {
  final seed = _bootMicroSignalSeed(index);
  return math.min(.90, seed.onset + seed.lifetime);
}

double _bootMicroSignalEnvelope(double progress, int index) {
  final local =
      ((progress - _bootMicroSignalOnset(index)) /
              (_bootMicroSignalEnd(index) - _bootMicroSignalOnset(index)))
          .clamp(0.0, 1.0)
          .toDouble();
  return math.sin(local * math.pi);
}

double _bootMicroSignalConvergence(double progress) =>
    Curves.easeIn.transform(((progress - .72) / .22).clamp(0.0, 1.0));

double _bootMicroSignalBaseX(Size size, int index) =>
    size.width * _bootMicroSignalSeed(index).x;

double _bootMicroSignalBaseY(Size size, int index) =>
    size.height * _bootMicroSignalSeed(index).y;

double _bootMicroSignalWidth(int index) =>
    switch (_bootMicroSignalType(index)) {
      _BootMicroSignalPrimitiveType.horizontalFragment =>
        7 + _bootMicroSignalSeed(index).width * 20,
      _BootMicroSignalPrimitiveType.microBlock =>
        2.5 + _bootMicroSignalSeed(index).width * 8.5,
      _BootMicroSignalPrimitiveType.signalSpeck =>
        1 + _bootMicroSignalSeed(index).width * 2.1,
      _BootMicroSignalPrimitiveType.offsetPair =>
        5 + _bootMicroSignalSeed(index).width * 17,
      _BootMicroSignalPrimitiveType.darkInterruption =>
        8 + _bootMicroSignalSeed(index).width * 17,
    };

double _bootMicroSignalHeight(int index) =>
    switch (_bootMicroSignalType(index)) {
      _BootMicroSignalPrimitiveType.horizontalFragment =>
        .9 + _bootMicroSignalSeed(index).height * .6,
      _BootMicroSignalPrimitiveType.microBlock =>
        1.3 + _bootMicroSignalSeed(index).height * 1.8,
      _BootMicroSignalPrimitiveType.signalSpeck =>
        .9 + _bootMicroSignalSeed(index).height * 1.2,
      _BootMicroSignalPrimitiveType.offsetPair =>
        .9 + _bootMicroSignalSeed(index).height * .6,
      _BootMicroSignalPrimitiveType.darkInterruption =>
        1 + _bootMicroSignalSeed(index).height * .9,
    };

double _bootMicroSignalOpacity(double progress, int index) {
  final type = _bootMicroSignalType(index);
  final typeIntensity = switch (type) {
    _BootMicroSignalPrimitiveType.horizontalFragment => .28,
    _BootMicroSignalPrimitiveType.microBlock => .23,
    _BootMicroSignalPrimitiveType.signalSpeck => .19,
    _BootMicroSignalPrimitiveType.offsetPair => .26,
    _BootMicroSignalPrimitiveType.darkInterruption => .17,
  };
  final build = Curves.easeOut.transform(
    ((progress - .10) / .34).clamp(0.0, 1.0),
  );
  final decay = 1 - _bootMicroSignalConvergence(progress);
  final seed = _bootMicroSignalSeed(index);
  final flicker =
      .72 + .28 * math.sin(progress * seed.frequency + seed.phase).abs();
  return _bootMicroSignalEnvelope(progress, index) *
      build *
      decay *
      typeIntensity *
      flicker;
}

Offset _bootMicroSignalPosition(Size size, double progress, int index) {
  final convergence = _bootMicroSignalConvergence(progress);
  final seed = _bootMicroSignalSeed(index);
  // Apply a seed-specific continuous drift before the short-lived flicker.
  // This keeps nearby sampled coordinates from resolving into visible lanes.
  final baseX =
      _bootMicroSignalBaseX(size, index) +
      math.sin(seed.phase + seed.y * 17.3) * size.width * .035;
  final baseY =
      _bootMicroSignalBaseY(size, index) +
      math.cos(seed.phase * 1.4 + seed.x * 13.7) * size.height * .018;
  final jitterX =
      math.sin(progress * (seed.frequency + 7) + seed.phase) *
      (1.5 + seed.width * 4.5) *
      (1 - convergence);
  final jitterY =
      math.cos(progress * (seed.frequency + 13) + seed.phase * 1.7) *
      (1 + seed.height * 3.2) *
      (1 - convergence);
  final lockX = size.width / 2 + (index.isEven ? -1 : 1) * (index % 5) * 3.5;
  return Offset(
    (baseX + jitterX) * (1 - convergence) + lockX * convergence,
    (baseY + jitterY) * (1 - convergence) + size.height / 2 * convergence,
  );
}

@visibleForTesting
BootMicroSignalFieldDiagnostics bootMicroSignalFieldDiagnosticsAt(
  Duration elapsed,
  Size size,
) {
  final progress =
      (elapsed.inMicroseconds / _microSignalAcquisitionDuration.inMicroseconds)
          .clamp(0.0, 1.0)
          .toDouble();
  var activeCount = 0;
  var minimumOpacity = double.infinity;
  var maximumOpacity = 0.0;
  var minimumWidth = double.infinity;
  var maximumWidth = 0.0;
  var minimumHeight = double.infinity;
  var maximumHeight = 0.0;
  var minimumY = double.infinity;
  var maximumY = 0.0;
  var aggregateWidth = 0.0;
  final activePositions = <Offset>[];
  final byType = <String, int>{
    for (final type in _BootMicroSignalPrimitiveType.values) type.name: 0,
  };

  for (var index = 0; index < bootMicroSignalFieldPrimitiveCount; index += 1) {
    final opacity = _bootMicroSignalOpacity(progress, index);
    if (opacity <= .012) continue;
    final position = _bootMicroSignalPosition(size, progress, index);
    final width = _bootMicroSignalWidth(index);
    final height = _bootMicroSignalHeight(index);
    activePositions.add(position);
    activeCount += 1;
    byType[_bootMicroSignalType(index).name] =
        byType[_bootMicroSignalType(index).name]! + 1;
    minimumOpacity = math.min(minimumOpacity, opacity);
    maximumOpacity = math.max(maximumOpacity, opacity);
    minimumWidth = math.min(minimumWidth, width);
    maximumWidth = math.max(maximumWidth, width);
    minimumHeight = math.min(minimumHeight, height);
    maximumHeight = math.max(maximumHeight, height);
    minimumY = math.min(minimumY, position.dy);
    maximumY = math.max(maximumY, position.dy + height);
    aggregateWidth +=
        width *
        (_bootMicroSignalType(index) == _BootMicroSignalPrimitiveType.offsetPair
            ? 2
            : 1);
  }
  var maximumNearColumnRun = 0;
  var maximumNearRowRun = 0;
  for (final position in activePositions) {
    final columnRun = activePositions
        .where(
          (other) =>
              (other.dx - position.dx).abs() < size.width * .014 &&
              (other.dy - position.dy).abs() > size.height * .065,
        )
        .length;
    final rowRun = activePositions
        .where(
          (other) =>
              (other.dy - position.dy).abs() < size.height * .014 &&
              (other.dx - position.dx).abs() > size.width * .07,
        )
        .length;
    maximumNearColumnRun = math.max(maximumNearColumnRun, columnRun);
    maximumNearRowRun = math.max(maximumNearRowRun, rowRun);
  }

  return BootMicroSignalFieldDiagnostics(
    elapsed: elapsed,
    activePrimitiveCount: activeCount,
    activeCountByType: Map.unmodifiable(byType),
    minimumEffectiveOpacity: activeCount == 0 ? 0 : minimumOpacity,
    maximumEffectiveOpacity: maximumOpacity,
    minimumLogicalWidth: activeCount == 0 ? 0 : minimumWidth,
    maximumLogicalWidth: maximumWidth,
    minimumLogicalHeight: activeCount == 0 ? 0 : minimumHeight,
    maximumLogicalHeight: maximumHeight,
    aggregateHorizontalCoverage: aggregateWidth / size.width,
    minimumVerticalFraction: activeCount == 0 ? .5 : minimumY / size.height,
    maximumVerticalFraction: activeCount == 0 ? .5 : maximumY / size.height,
    maximumNearColumnRun: maximumNearColumnRun,
    maximumNearRowRun: maximumNearRowRun,
  );
}

@visibleForTesting
double bootSignalRestoreProgress(double progress) => Curves.easeInOutCubic
    .transform(((progress - .25) / .70).clamp(0.0, 1.0).toDouble());

@visibleForTesting
double bootSignalRestoreHeightFraction(double progress) =>
    .02 + .98 * bootSignalRestoreProgress(progress);

@visibleForTesting
double bootSignalContentScaleY(double progress) =>
    bootSignalRestoreHeightFraction(progress);

@visibleForTesting
double bootSignalSliceOffset(double progress, int index) {
  // Start the signal fragments sooner and let them settle at .95. This keeps
  // a short, fully restored frame inside the fixed 450ms intro before the
  // official logo begins, while making the fragmented signal readable.
  final start = index * .025;
  final end = .66 + (index % 3) * .09 + (index == 5 ? .11 : 0);
  final local = ((progress - start) / (end - start)).clamp(0.0, 1.0).toDouble();
  final envelope = math.sin(local * math.pi);
  final direction = index.isEven ? 1.0 : -1.0;
  final amplitude = 7 + index * 2.6;
  final flutter = .72 + .28 * math.sin(progress * (18 + index * 4));
  return direction * amplitude * envelope * flutter;
}

@visibleForTesting
double bootSignalLineOpacity(double progress) =>
    math.pow(1 - bootSignalRestoreProgress(progress), .72).toDouble();

@visibleForTesting
double bootIntroSilhouetteOpacity(double progress) {
  final rise = Curves.easeOut.transform(
    ((progress - .02) / .18).clamp(0.0, 1.0),
  );
  final heavyGlitch = math.sin(
    ((progress - .08) / .54).clamp(0.0, 1.0).toDouble() * math.pi,
  );
  final decay =
      1 - Curves.easeIn.transform(((progress - .70) / .25).clamp(0.0, 1.0));
  // The ghost is legible only during the unstable signal window. Its .35
  // peak remains distinctly below the official logo's full-opacity reveal.
  return (.09 + .22 * rise + .04 * heavyGlitch) * decay;
}

/// A small deterministic visual timeline. It does not represent persistence
/// work and remains independent from the real initialization state.
class BootSequenceTiming {
  /// The sole production selector for the pre-Ghost acquisition renderer.
  /// Changing this default is the complete emergency rollback mechanism.
  final BootSignalMode signalMode;
  final Duration signalAcquisitionIntro;
  final Duration preBootSignalIntro;
  final Duration logoIntro;
  final bool waitForLogoDrawable;
  final Duration typingCharacter;
  final Duration fullNameCharacter;
  final Duration identityHold;
  final Duration systemBootTransition;
  final Duration header;
  final Duration row;
  final Duration readyDelay;
  final Duration readyHold;
  final double postLogoTimingFactor;

  const BootSequenceTiming({
    this.signalMode = BootSignalMode.microSignalField,
    Duration? signalAcquisitionIntro,
    this.preBootSignalIntro = const Duration(milliseconds: 450),
    this.logoIntro = const Duration(milliseconds: 600),
    this.waitForLogoDrawable = true,
    this.typingCharacter = const Duration(milliseconds: 120),
    this.fullNameCharacter = const Duration(milliseconds: 14),
    this.identityHold = const Duration(milliseconds: 230),
    this.systemBootTransition = const Duration(milliseconds: 190),
    this.header = const Duration(milliseconds: 180),
    this.row = const Duration(milliseconds: 280),
    this.readyDelay = const Duration(milliseconds: 210),
    this.readyHold = const Duration(milliseconds: 400),
    this.postLogoTimingFactor = postLogoBootTimingFactor,
  }) : signalAcquisitionIntro =
           signalAcquisitionIntro ??
           (signalMode == BootSignalMode.microSignalField
               ? _microSignalAcquisitionDuration
               : _legacySignalAcquisitionDuration);

  Duration postLogo(Duration duration) => Duration(
    microseconds: (duration.inMicroseconds * postLogoTimingFactor).round(),
  );
}

enum _BootVisualPhase {
  logo,
  identityTyping,
  identityName,
  axisIdentity,
  systemBoot,
  coreInitializing,
  dataInitializing,
  operationInitializing,
  waitingForInitialization,
  finalizing,
  systemReady,
}

enum BootPresentationState {
  initialBootPresentation,
  systemReadyPresentation,
  bootHandoffSignal,
  skipped,
  reinitializationLoading,
  mainUi,
  failure,
}

class BootStartupTraceEvent {
  final DateTime occurredAt;
  final String event;
  final BootPresentationState previousState;
  final BootPresentationState nextState;
  final PersistenceMode initializationMode;
  final String visualPhase;
  final int session;

  const BootStartupTraceEvent({
    required this.occurredAt,
    required this.event,
    required this.previousState,
    required this.nextState,
    required this.initializationMode,
    required this.visualPhase,
    required this.session,
  });

  @override
  String toString() =>
      'STARTUP_TRACE t=$occurredAt event=$event session=$session '
      'startup=${initializationMode.name} boot=${nextState.name} '
      'visual=$visualPhase';
}

typedef BootStartupTraceListener = void Function(BootStartupTraceEvent event);

class _BootSequenceVisual extends StatefulWidget {
  final _BootVisualPhase phase;
  final int typedLength;
  final int typedNameLength;
  final int typedAxisLength;
  final double progress;
  final Duration logoFadeDuration;
  final Duration signalAcquisitionIntroDuration;
  final BootSignalMode signalMode;
  final Duration preBootSignalIntroDuration;
  final bool waitForLogoDrawable;
  final VoidCallback onLogoFadeComplete;
  final VoidCallback onSkip;

  const _BootSequenceVisual({
    required this.phase,
    required this.typedLength,
    required this.typedNameLength,
    required this.typedAxisLength,
    required this.progress,
    required this.logoFadeDuration,
    required this.signalAcquisitionIntroDuration,
    required this.signalMode,
    required this.preBootSignalIntroDuration,
    required this.waitForLogoDrawable,
    required this.onLogoFadeComplete,
    required this.onSkip,
  });

  @override
  State<_BootSequenceVisual> createState() => _BootSequenceVisualState();
}

class _BootSequenceVisualState extends State<_BootSequenceVisual>
    with TickerProviderStateMixin {
  static const _logoProvider = AssetImage(
    'assets/icons/orlo_logo_1024_transparent.png',
  );
  late final AnimationController _cursorController;
  late final AnimationController _signalAcquisitionController;
  late final AnimationController _preBootSignalController;
  late final AnimationController _logoFadeController;
  late final AnimationController _spinnerController;
  late final ImageStreamListener _logoImageListener;
  ImageStream? _logoImageStream;
  bool _logoFadeQueued = false;
  bool _logoFadeStarted = false;
  bool _logoFadeCompleted = false;
  bool _signalAcquisitionComplete = false;
  bool _preBootSignalComplete = false;
  bool _logoDrawable = false;
  bool _logoLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _signalAcquisitionController =
        AnimationController(
          vsync: this,
          duration: widget.signalAcquisitionIntroDuration,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            if (mounted) {
              setState(() => _signalAcquisitionComplete = true);
            } else {
              _signalAcquisitionComplete = true;
            }
            _startGhostReconstruction();
          }
        });
    _preBootSignalController =
        AnimationController(
          vsync: this,
          duration: widget.preBootSignalIntroDuration,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            if (mounted) {
              setState(() => _preBootSignalComplete = true);
            } else {
              _preBootSignalComplete = true;
            }
            _tryBeginLogoFade();
          }
        });
    _logoFadeController =
        AnimationController(vsync: this, duration: widget.logoFadeDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _completeLogoFade();
            }
          });
    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _logoImageListener = ImageStreamListener(
      (_, _) {
        _logoDrawable = true;
        _tryBeginLogoFade();
      },
      onError: (_, _) {
        _logoLoadFailed = true;
        _tryBeginLogoFade();
      },
    );
    if (widget.signalAcquisitionIntroDuration == Duration.zero) {
      _signalAcquisitionComplete = true;
      _startGhostReconstruction();
    } else {
      _signalAcquisitionController.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_logoImageStream != null) return;
    _logoImageStream = _logoProvider.resolve(
      createLocalImageConfiguration(context),
    )..addListener(_logoImageListener);
    if (!widget.waitForLogoDrawable) _tryBeginLogoFade();
  }

  @override
  void didUpdateWidget(covariant _BootSequenceVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasActive = _isInitializing(oldWidget.phase);
    final isActive = _isInitializing(widget.phase);
    if (isActive && oldWidget.phase != widget.phase) {
      _spinnerController
        ..reset()
        ..repeat();
    } else if (wasActive && !isActive) {
      _spinnerController.stop();
    }
  }

  @override
  void dispose() {
    _logoImageStream?.removeListener(_logoImageListener);
    _cursorController.dispose();
    _signalAcquisitionController.dispose();
    _preBootSignalController.dispose();
    _logoFadeController.dispose();
    _spinnerController.dispose();
    super.dispose();
  }

  void _tryBeginLogoFade() {
    if (!_preBootSignalComplete) return;
    if (_logoLoadFailed && widget.waitForLogoDrawable) {
      _skipLogoFadeAfterImageError();
      return;
    }
    if (widget.waitForLogoDrawable && !_logoDrawable) return;
    if (_logoFadeStarted || _logoFadeQueued) return;
    _logoFadeQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _logoFadeStarted) return;
      _logoFadeStarted = true;
      _logoFadeController.forward();
    });
  }

  void _startGhostReconstruction() {
    if (widget.preBootSignalIntroDuration == Duration.zero) {
      _preBootSignalComplete = true;
      _tryBeginLogoFade();
      return;
    }
    _preBootSignalController.forward();
  }

  void _completeLogoFade() {
    if (_logoFadeCompleted) return;
    _logoFadeCompleted = true;
    widget.onLogoFadeComplete();
  }

  void _skipLogoFadeAfterImageError() {
    if (_logoFadeQueued || _logoFadeCompleted) return;
    _logoFadeQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _completeLogoFade();
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _spinnerController,
    builder: (context, _) => _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: bootBackgroundColor,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _BootContentRestore(
                progress: _preBootSignalController,
                active: _signalAcquisitionComplete && !_preBootSignalComplete,
                contentBuilder: (includeKeys, introProgress) =>
                    _buildBootContentLayer(
                      colorScheme,
                      widget.phase,
                      includeKeys,
                      introProgress,
                      widget.typedAxisLength,
                    ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 12,
              child: Semantics(
                button: true,
                label: 'TAP TO SKIP',
                child: SizedBox(
                  height: 48,
                  child: TextButton(
                    key: const ValueKey('boot-tap-to-skip'),
                    onPressed: widget.onSkip,
                    child: Text(
                      'TAP TO SKIP',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary.withValues(alpha: .72),
                        fontFamily: _bootTerminalFontFamily,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.35,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!_signalAcquisitionComplete)
              Positioned.fill(
                child: IgnorePointer(
                  child: KeyedSubtree(
                    key: ValueKey('boot-signal-mode-${widget.signalMode.name}'),
                    child: CustomPaint(
                      key: const ValueKey('boot-signal-acquisition'),
                      painter: switch (widget.signalMode) {
                        BootSignalMode.legacyInterference =>
                          _BootLegacySignalAcquisitionPainter(
                            _signalAcquisitionController,
                          ),
                        BootSignalMode.microSignalField =>
                          _BootMicroSignalFieldPainter(
                            _signalAcquisitionController,
                          ),
                      },
                    ),
                  ),
                ),
              ),
            if (_signalAcquisitionComplete && !_preBootSignalComplete)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const ValueKey('boot-pre-signal-intro'),
                    painter: _BootPreSignalPainter(_preBootSignalController),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBootContentLayer(
    ColorScheme colorScheme,
    _BootVisualPhase phase,
    bool includeKeys,
    double introProgress,
    int typedAxisLength,
  ) {
    final rows = <Widget>[
      if (phase.index >= _BootVisualPhase.coreInitializing.index)
        _BootStatusLine(
          key: const ValueKey('boot-row-core'),
          label: 'CORE SYSTEM',
          initializing: phase == _BootVisualPhase.coreInitializing,
          spinner: _spinnerCharacter,
        ),
      if (phase.index >= _BootVisualPhase.dataInitializing.index)
        _BootStatusLine(
          key: const ValueKey('boot-row-data'),
          label: 'DATA INITIALIZATION',
          initializing: phase == _BootVisualPhase.dataInitializing,
          spinner: _spinnerCharacter,
        ),
      if (phase.index >= _BootVisualPhase.operationInitializing.index)
        _BootStatusLine(
          key: const ValueKey('boot-row-operation'),
          label: 'OPERATION DATA',
          initializing: phase == _BootVisualPhase.operationInitializing,
          spinner: _spinnerCharacter,
        ),
    ];
    final hasActiveRow =
        phase == _BootVisualPhase.coreInitializing ||
        phase == _BootVisualPhase.dataInitializing ||
        phase == _BootVisualPhase.operationInitializing;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: Colors.white70,
              fontFamily: _bootTerminalFontFamily,
              fontWeight: FontWeight.w400,
              letterSpacing: .45,
              height: 1.24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BootLogoSlot(
                  logoProvider: _logoProvider,
                  officialFade: _logoFadeController,
                  introSilhouetteOpacity: bootIntroSilhouetteOpacity(
                    introProgress,
                  ),
                  includeKeys: includeKeys,
                  onOfficialLogoError: () {
                    _logoLoadFailed = true;
                    _tryBeginLogoFade();
                  },
                ),
                if (phase.index >= _BootVisualPhase.identityTyping.index) ...[
                  const SizedBox(height: 16),
                  Text(
                    'O.R.L.O.'.substring(0, widget.typedLength),
                    key: includeKeys
                        ? const ValueKey('boot-brand-identity')
                        : null,
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      color: colorScheme.primary,
                      fontFamily: _bootTerminalFontFamily,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 2.8,
                    ),
                  ),
                ],
                if (phase.index >= _BootVisualPhase.identityName.index)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _fullName.substring(0, widget.typedNameLength),
                        key: includeKeys
                            ? const ValueKey('boot-brand-full-name')
                            : null,
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          color: colorScheme.primary.withValues(alpha: .7),
                          fontFamily: _bootTerminalFontFamily,
                          fontWeight: FontWeight.w400,
                          letterSpacing: .55,
                        ),
                      ),
                    ),
                  ),
                if (phase.index >= _BootVisualPhase.axisIdentity.index)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      OperationSystemMetadata.version.substring(
                        0,
                        typedAxisLength,
                      ),
                      key: includeKeys
                          ? const ValueKey('boot-operation-system-version')
                          : null,
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: colorScheme.primary.withValues(alpha: .48),
                        fontFamily: _bootTerminalFontFamily,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.15,
                      ),
                    ),
                  ),
                if (phase == _BootVisualPhase.identityTyping)
                  FadeTransition(
                    opacity: _cursorController,
                    child: Text(
                      '▌',
                      key: includeKeys
                          ? const ValueKey('boot-typing-cursor')
                          : null,
                      style: TextStyle(color: colorScheme.primary),
                    ),
                  ),
                if (phase.index >= _BootVisualPhase.systemBoot.index) ...[
                  const SizedBox(height: 16),
                  Text(
                    'SYSTEM BOOT',
                    style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      color: colorScheme.primary.withValues(alpha: .82),
                      fontFamily: _bootTerminalFontFamily,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _BootProgressBar(value: widget.progress),
                ],
                if (rows.isNotEmpty) const SizedBox(height: 28),
                ...rows,
                if (hasActiveRow) const SizedBox(height: 8),
                if (phase == _BootVisualPhase.systemReady) ...[
                  const SizedBox(height: 28),
                  Text(
                    'SYSTEM READY',
                    key: includeKeys
                        ? const ValueKey('boot-system-ready')
                        : null,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _spinnerCharacter {
    return switch ((_spinnerController.value * 4).floor().clamp(0, 3)) {
      0 => '/',
      1 => '|',
      2 => '\\',
      _ => '-',
    };
  }

  bool _isInitializing(_BootVisualPhase phase) =>
      phase == _BootVisualPhase.coreInitializing ||
      phase == _BootVisualPhase.dataInitializing ||
      phase == _BootVisualPhase.operationInitializing;
}

class _BootLogoSlot extends StatelessWidget {
  const _BootLogoSlot({
    required this.logoProvider,
    required this.officialFade,
    required this.introSilhouetteOpacity,
    required this.includeKeys,
    required this.onOfficialLogoError,
  });

  final ImageProvider<Object> logoProvider;
  final Animation<double> officialFade;
  final double introSilhouetteOpacity;
  final bool includeKeys;
  final VoidCallback onOfficialLogoError;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 128,
    width: 220,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (introSilhouetteOpacity > 0)
          Opacity(
            key: includeKeys
                ? const ValueKey('boot-intro-logo-silhouette')
                : null,
            opacity: introSilhouetteOpacity,
            child: ExcludeSemantics(
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Color(0xFF9ABAC6),
                  BlendMode.srcIn,
                ),
                child: Image(
                  image: logoProvider,
                  height: 128,
                  width: 220,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        FadeTransition(
          key: includeKeys ? const ValueKey('boot-brand-logo-fade') : null,
          opacity: CurvedAnimation(parent: officialFade, curve: Curves.easeOut),
          child: Image(
            image: logoProvider,
            key: includeKeys ? const ValueKey('boot-brand-logo') : null,
            height: 128,
            width: 220,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) {
              onOfficialLogoError();
              return const SizedBox(height: 72);
            },
          ),
        ),
      ],
    ),
  );
}

class _BootContentRestore extends StatelessWidget {
  const _BootContentRestore({
    required this.progress,
    required this.active,
    required this.contentBuilder,
  });

  static const _sliceCount = 6;

  final Animation<double> progress;
  final bool active;
  final Widget Function(bool includeKeys, double introProgress) contentBuilder;

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return KeyedSubtree(
        key: const ValueKey('boot-content-normal'),
        child: contentBuilder(true, 1),
      );
    }
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final scaleY = bootSignalContentScaleY(progress.value);
        return Stack(
          key: const ValueKey('boot-content-transform'),
          fit: StackFit.expand,
          children: [
            for (var index = 0; index < _sliceCount; index += 1)
              ClipRect(
                clipper: _BootContentSliceClipper(index, _sliceCount),
                child: Transform.translate(
                  offset: Offset(
                    bootSignalSliceOffset(progress.value, index),
                    0,
                  ),
                  child: Transform.scale(
                    alignment: Alignment.center,
                    scaleY: scaleY,
                    child: KeyedSubtree(
                      key: ValueKey('boot-content-slice-$index'),
                      child: contentBuilder(index == 0, progress.value),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BootContentSliceClipper extends CustomClipper<Rect> {
  const _BootContentSliceClipper(this.index, this.count);

  final int index;
  final int count;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    0,
    size.height * index / count,
    size.width,
    size.height / count,
  );

  @override
  bool shouldReclip(covariant _BootContentSliceClipper oldClipper) =>
      oldClipper.index != index || oldClipper.count != count;
}

/// Preserves the pre-pivot acquisition implementation for a one-point
/// production rollback through [BootSequenceTiming.signalMode].
class _BootLegacySignalAcquisitionPainter extends CustomPainter {
  const _BootLegacySignalAcquisitionPainter(this.progress)
    : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = progress.value;
    final centerY = size.height / 2;
    final lineOpacity = bootSignalAcquisitionLineOpacity(frame);
    final detection = Curves.easeOut.transform((frame / .24).clamp(0.0, 1.0));
    final lineWidth = size.width * (.18 + .64 * detection);
    final lineLeft = (size.width - lineWidth) / 2;
    final lineJitter = math.sin(frame * 49) * (1.8 - frame * .8);
    final lineThickness = 1.2 + 1.1 * math.sin(frame * 37).abs();
    final halo = Paint()
      ..color = bootSignalHaloColor.withValues(alpha: lineOpacity * .74);
    final core = Paint()
      ..color = bootSignalCoreColor.withValues(alpha: lineOpacity);
    canvas.drawRect(
      Rect.fromLTWH(
        lineLeft,
        centerY + lineJitter - lineThickness,
        lineWidth,
        lineThickness * 3,
      ),
      halo,
    );
    canvas.drawRect(
      Rect.fromLTWH(lineLeft, centerY + lineJitter, lineWidth, lineThickness),
      core,
    );

    // Fine, non-uniform fragments make the acquisition read as an unstable
    // video feed. Their positions, widths, lifetimes, and offsets are all
    // deterministic: no runtime noise texture or random allocation is used.
    final fragments = Paint();
    for (
      var index = 0;
      index < bootSignalAcquisitionFineSegmentCount;
      index += 1
    ) {
      final y = _bootSignalFineFragmentY(size, frame, index);
      final start = _bootSignalFineFragmentStart(size, frame, index);
      final width = _bootSignalFineFragmentWidth(size, index);
      final alpha = _bootSignalFineFragmentOpacity(frame, index);
      fragments.color = bootSignalFragmentColor.withValues(alpha: alpha);
      canvas.drawRect(
        Rect.fromLTWH(
          start,
          y,
          width,
          _bootSignalFineFragmentStrokeWidth(index),
        ),
        fragments,
      );
    }

    // A few wider displaced fragments organize the fine interference around
    // the lock line, giving the final acquisition frames a clear direction
    // into the existing Ghost reconstruction.
    for (
      var index = 0;
      index < _bootSignalAcquisitionLockFragmentCount;
      index += 1
    ) {
      final y = _bootSignalLockFragmentY(size, centerY, lineJitter, index);
      final start = _bootSignalLockFragmentStart(size, frame, index);
      final width = _bootSignalLockFragmentWidth(size, index);
      fragments.color = bootSignalFragmentColor.withValues(
        alpha: _bootSignalLockFragmentOpacity(frame),
      );
      canvas.drawRect(Rect.fromLTWH(start, y, width, 1.1), fragments);
    }
  }

  @override
  bool shouldRepaint(
    covariant _BootLegacySignalAcquisitionPainter oldDelegate,
  ) => false;
}

/// A deterministic field of small scan-shaped primitives. It intentionally
/// avoids assets, textures, and random runtime generation: each frame draws
/// from the same fixed primitive definitions and temporal envelopes.
class _BootMicroSignalFieldPainter extends CustomPainter {
  const _BootMicroSignalFieldPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = progress.value;
    final light = Paint();
    final dark = Paint();

    for (
      var index = 0;
      index < bootMicroSignalFieldPrimitiveCount;
      index += 1
    ) {
      final opacity = _bootMicroSignalOpacity(frame, index);
      if (opacity <= .004) continue;
      final position = _bootMicroSignalPosition(size, frame, index);
      final width = _bootMicroSignalWidth(index);
      final height = _bootMicroSignalHeight(index);
      final type = _bootMicroSignalType(index);
      final rect = Rect.fromLTWH(position.dx, position.dy, width, height);

      if (type == _BootMicroSignalPrimitiveType.darkInterruption) {
        dark.color = bootBackgroundColor.withValues(alpha: opacity * .8);
        canvas.drawRect(rect, dark);
        continue;
      }

      light.color = bootSignalFragmentColor.withValues(alpha: opacity);
      canvas.drawRect(rect, light);
      if (type == _BootMicroSignalPrimitiveType.offsetPair) {
        final pairOffset = 8 + (index % 4) * 3.5;
        canvas.drawRect(
          Rect.fromLTWH(
            (position.dx + pairOffset).clamp(0.0, size.width).toDouble(),
            position.dy + (index.isEven ? 1.8 : -1.8),
            width * .7,
            height,
          ),
          light,
        );
      }
    }

    // The field gradually organizes around a short central structure in the
    // final acquisition frames. It shares the same 300ms boundary as legacy
    // mode and hands directly to the unchanged Ghost reconstruction.
    final lock = Curves.easeInOut.transform(
      ((frame - .78) / .22).clamp(0.0, 1.0),
    );
    if (lock > 0) {
      final centerY = size.height / 2;
      final width = size.width * (.18 + .55 * lock);
      final thickness = 1.1 + lock * .7;
      final halo = Paint()
        ..color = bootSignalHaloColor.withValues(alpha: lock * .42);
      final core = Paint()
        ..color = bootSignalCoreColor.withValues(alpha: lock * .72);
      canvas.drawRect(
        Rect.fromLTWH(
          (size.width - width) / 2,
          centerY - thickness,
          width,
          thickness * 3,
        ),
        halo,
      );
      canvas.drawRect(
        Rect.fromLTWH((size.width - width) / 2, centerY, width, thickness),
        core,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BootMicroSignalFieldPainter oldDelegate) =>
      false;
}

class _BootPreSignalPainter extends CustomPainter {
  const _BootPreSignalPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = progress.value;
    final centerY = size.height / 2;
    final lineProgress = (frame / .18).clamp(0.0, 1.0);
    final restored = bootSignalRestoreProgress(frame);
    final lineOpacity = bootSignalLineOpacity(frame);
    final lineFlicker = math.sin(frame * 83) * .7 * lineOpacity;
    final lineJitter = math.sin(frame * 61) * 2.4 * lineOpacity;
    final lineThickness = 1.1 + (math.sin(frame * 47) + 1) * 1.05;

    final endpointFlicker = math.sin(frame * 39) * 7 * lineOpacity;
    final lineWidth =
        (size.width * (.35 + .65 * lineProgress) + endpointFlicker)
            .clamp(0.0, size.width)
            .toDouble();
    final lineLeft = (size.width - lineWidth) / 2;
    final halo = Paint()
      ..color = bootSignalHaloColor.withValues(
        alpha: (.68 + lineFlicker * .22).clamp(0.0, .94) * lineOpacity,
      );
    final core = Paint()
      ..color = bootSignalCoreColor.withValues(alpha: lineOpacity);
    canvas.drawRect(
      Rect.fromLTWH(
        lineLeft,
        centerY + lineJitter - lineThickness * 2.2,
        lineWidth,
        lineThickness * 4.8,
      ),
      halo,
    );
    canvas.drawRect(
      Rect.fromLTWH(lineLeft, centerY + lineJitter, lineWidth, lineThickness),
      core,
    );

    if (frame >= .12 && frame < .78) {
      final scanOpacity = (1 - restored) * .18;
      for (var index = 0; index < 3; index += 1) {
        final scanProgress = (frame * (3.1 + index * .21) + index * .29) % 1;
        final y = centerY + (scanProgress - .5) * size.height * restored;
        final scanPaint = Paint()
          ..color = bootSignalFragmentColor.withValues(
            alpha: scanOpacity * (1 - index * .12),
          );
        canvas.drawRect(
          Rect.fromLTWH(0, y, size.width, 1 + (index.isEven ? .5 : 0)),
          scanPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BootPreSignalPainter oldDelegate) => false;
}

class _BootStatusLine extends StatelessWidget {
  final String label;
  final bool initializing;
  final String spinner;

  const _BootStatusLine({
    super.key,
    required this.label,
    required this.initializing,
    required this.spinner,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      Text(
        initializing ? 'INITIALIZING $spinner' : 'OK',
        style: TextStyle(
          color: initializing
              ? Colors.white
              : Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _BootProgressBar extends StatelessWidget {
  const _BootProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Boot progress',
      value: '${(value * 100).round()}%',
      child: Container(
        key: const ValueKey('boot-progress-bar'),
        height: 10,
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: .45)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                key: const ValueKey('boot-progress-track'),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: constraints.maxWidth * value.clamp(0, 1),
                child: DecoratedBox(
                  key: const ValueKey('boot-progress-fill'),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .95),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootSignalHandoff extends StatefulWidget {
  const _BootSignalHandoff({required this.duration});

  final Duration duration;

  @override
  State<_BootSignalHandoff> createState() => _BootSignalHandoffState();
}

class _BootSignalHandoffState extends State<_BootSignalHandoff>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('boot-signal-handoff'),
    color: Colors.black,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => CustomPaint(
        key: const ValueKey('boot-signal-sync-sweep'),
        painter: BootSignalHandoffPainter(_controller.value),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class BootSignalHandoffPainter extends CustomPainter {
  const BootSignalHandoffPainter(this.frame);
  final double frame;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * frame;
    final core = Paint()..color = bootSignalCoreColor;
    final halo = Paint()..color = bootSignalHaloColor;
    canvas.drawRect(Rect.fromLTWH(0, y - 2, size.width, 5), halo);
    canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1.5), core);

    // A few short fragments immediately trail the sync line. They establish
    // motion without turning the entire frame into static or placeholder bars.
    final fragments = Paint()..color = bootSignalFragmentColor;
    for (var index = 0; index < 3; index += 1) {
      final start =
          (size.width * (.12 + index * .27) + frame * 43) % size.width;
      final width = size.width * (.08 + index * .025);
      canvas.drawRect(
        Rect.fromLTWH(start, y + 4 + index * 2, width, 1),
        fragments,
      );
    }
  }

  @override
  bool shouldRepaint(BootSignalHandoffPainter oldDelegate) =>
      oldDelegate.frame != frame;
}

/// Coordinates the visual without owning initialization or persistence.
class BootSequenceGate extends StatefulWidget {
  final ValueListenable<AppInitializationState> initialization;
  final Widget child;
  final Widget Function(AppInitializationState state) fallbackBuilder;
  final BootSequenceTiming timing;
  final BootSequenceEventListener? onEvent;
  final bool isInitialBootPresentation;
  final BootStartupTraceListener? onTrace;
  final VoidCallback? onPresentationReleased;

  /// Reserved for a future explicit audio experience. Boot currently does not
  /// invoke audio playback.
  final BootAudio? bootAudio;

  const BootSequenceGate({
    super.key,
    required this.initialization,
    required this.child,
    required this.fallbackBuilder,
    this.timing = const BootSequenceTiming(),
    this.onEvent,
    this.isInitialBootPresentation = true,
    this.onTrace,
    this.onPresentationReleased,
    this.bootAudio,
  });

  @override
  State<BootSequenceGate> createState() => _BootSequenceGateState();
}

class _BootSequenceGateState extends State<BootSequenceGate>
    with SingleTickerProviderStateMixin {
  static const _axisTypingCharacter = Duration(milliseconds: 27);
  Timer? _timelineTimer;
  late final AnimationController _progressController;
  int _session = 0;
  bool _systemInitialized = false;
  bool _visualRowsComplete = false;
  bool _finalProgressStarted = false;
  bool _readyDelayElapsed = false;
  bool _skipRequested = false;
  bool _logoFadeCompleted = false;
  bool _presentationReleased = false;
  String? _lastDiagnosticPresentation;
  BootPresentationState _presentation =
      BootPresentationState.initialBootPresentation;
  int _typedLength = 0;
  int _typedNameLength = 0;
  int _typedAxisLength = 0;
  _BootVisualPhase _phase = _BootVisualPhase.logo;

  @override
  void initState() {
    super.initState();
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'BOOT_GATE_INIT',
      presentation: widget.isInitialBootPresentation ? 'BOOT' : 'INITIALIZING',
      fields: {
        'bootGate': identityHashCode(this),
        'initialBootPresentation': widget.isInitialBootPresentation,
      },
    );
    _progressController = AnimationController(vsync: this);
    widget.initialization.addListener(_onInitializationChanged);
    if (!widget.isInitialBootPresentation) {
      _transition(
        BootPresentationState.reinitializationLoading,
        'gate_created_after_initial_boot_claim',
      );
      return;
    }
    _emit(BootSequenceEventType.bootStart);
    _trace('boot_gate_created');
    _onInitializationChanged();
  }

  @override
  void dispose() {
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'BOOT_GATE_DISPOSE',
      presentation: _diagnosticPresentation,
      fields: {'presentationReleased': _presentationReleased},
    );
    widget.initialization.removeListener(_onInitializationChanged);
    _invalidateSession('gate_disposed');
    _progressController.dispose();
    super.dispose();
  }

  void _schedule(Duration duration, VoidCallback action) {
    _timelineTimer?.cancel();
    final scheduledSession = _session;
    _timelineTimer = Timer(duration, () {
      if (!mounted || scheduledSession != _session) {
        _trace('obsolete_callback_ignored');
        return;
      }
      action();
    });
  }

  void _invalidateSession(String event) {
    _timelineTimer?.cancel();
    _timelineTimer = null;
    _progressController.stop();
    _session += 1;
    _trace(event);
  }

  bool get _isPresentationActive =>
      widget.isInitialBootPresentation &&
      (_presentation == BootPresentationState.initialBootPresentation ||
          _presentation == BootPresentationState.systemReadyPresentation);

  bool get _isInitializationReady {
    final mode = widget.initialization.value.mode;
    return mode != PersistenceMode.initializing &&
        mode != PersistenceMode.failed;
  }

  void _startIdentityTyping() {
    if (!_isPresentationActive) return;
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'BOOT_PHASE_TYPING',
      presentation: 'BOOT',
    );
    setState(() => _phase = _BootVisualPhase.identityTyping);
    _animateProgressTo(
      .2,
      widget.timing.postLogo(const Duration(milliseconds: 1500)),
    );
    _typeNextCharacter();
  }

  void _startIdentityTypingAfterLogoFade() {
    if (_logoFadeCompleted || !_isPresentationActive) return;
    _logoFadeCompleted = true;
    _startIdentityTyping();
  }

  void _typeNextCharacter() {
    if (!_isPresentationActive) return;
    const identity = 'O.R.L.O.';
    if (_typedLength >= identity.length) {
      setState(() => _phase = _BootVisualPhase.identityName);
      _typeNextNameCharacter();
      return;
    }
    _schedule(_identityCharacterDelay(_typedLength), () {
      setState(() => _typedLength += 1);
      _typeNextCharacter();
    });
  }

  Duration _identityCharacterDelay(int index) {
    // Compact injected timings keep controlled widget tests fast.
    final duration = widget.timing.postLogo(widget.timing.typingCharacter);
    if (duration <= const Duration(milliseconds: 100)) {
      return duration;
    }
    return widget.timing.postLogo(
      const [
        Duration(milliseconds: 170),
        Duration(milliseconds: 160),
        Duration(milliseconds: 145),
        Duration(milliseconds: 135),
        Duration(milliseconds: 125),
        Duration(milliseconds: 115),
        Duration(milliseconds: 95),
        Duration(milliseconds: 75),
      ][index.clamp(0, 7)],
    );
  }

  void _typeNextNameCharacter() {
    if (!_isPresentationActive) return;
    final duration = widget.timing.postLogo(widget.timing.fullNameCharacter);
    if (duration <= const Duration(milliseconds: 10)) {
      setState(() => _typedNameLength = _fullName.length);
      _showAxisIdentity();
      return;
    }
    if (_typedNameLength >= _fullName.length) {
      _showAxisIdentity();
      return;
    }
    _schedule(duration, () {
      setState(() => _typedNameLength += 1);
      _typeNextNameCharacter();
    });
  }

  void _showAxisIdentity() {
    if (!_isPresentationActive) return;
    setState(() {
      _phase = _BootVisualPhase.axisIdentity;
      _typedAxisLength = 0;
    });
    if (widget.timing.fullNameCharacter <= const Duration(milliseconds: 10)) {
      setState(() => _typedAxisLength = OperationSystemMetadata.version.length);
      _schedule(
        widget.timing.postLogo(widget.timing.identityHold),
        _showSystemBoot,
      );
      return;
    }
    _typeNextAxisCharacter();
  }

  void _typeNextAxisCharacter() {
    if (!_isPresentationActive) return;
    if (_typedAxisLength >= OperationSystemMetadata.version.length) {
      _schedule(_axisIdentitySettleDuration, _showSystemBoot);
      return;
    }
    _schedule(widget.timing.postLogo(_axisTypingCharacter), () {
      setState(() => _typedAxisLength += 1);
      _typeNextAxisCharacter();
    });
  }

  Duration get _axisIdentitySettleDuration {
    final identityHold = widget.timing.postLogo(widget.timing.identityHold);
    final typingDuration =
        widget.timing.postLogo(_axisTypingCharacter) *
        OperationSystemMetadata.version.length;
    final remaining = identityHold - typingDuration;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _showSystemBoot() {
    if (!_isPresentationActive) return;
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'BOOT_PHASE_PROGRESS',
      presentation: 'BOOT',
    );
    setState(() => _phase = _BootVisualPhase.systemBoot);
    final duration = widget.timing.postLogo(widget.timing.systemBootTransition);
    _animateProgressTo(.25, duration);
    _schedule(duration, _showCore);
  }

  void _showCore() {
    if (!_isPresentationActive) return;
    setState(() => _phase = _BootVisualPhase.coreInitializing);
    final coreDuration = widget.timing.postLogo(widget.timing.row) * 2;
    _animateProgressTo(.45, coreDuration);
    _schedule(coreDuration, _showData);
  }

  void _showData() {
    if (!_isPresentationActive) return;
    setState(() => _phase = _BootVisualPhase.dataInitializing);
    final duration = widget.timing.postLogo(widget.timing.row);
    _animateProgressTo(.65, duration);
    _schedule(duration, _showOperation);
  }

  void _showOperation() {
    if (!_isPresentationActive) return;
    setState(() => _phase = _BootVisualPhase.operationInitializing);
    final duration = widget.timing.postLogo(widget.timing.row);
    _animateProgressTo(.95, duration);
    _schedule(duration, _finishRows);
  }

  void _finishRows() {
    if (!_isPresentationActive) return;
    setState(() => _phase = _BootVisualPhase.waitingForInitialization);
    _visualRowsComplete = true;
    _tryStartFinalProgress();
  }

  void _tryStartFinalProgress() {
    if (!_isPresentationActive ||
        !_visualRowsComplete ||
        !_systemInitialized ||
        _finalProgressStarted) {
      return;
    }
    _finalProgressStarted = true;
    setState(() => _phase = _BootVisualPhase.finalizing);
    final duration = widget.timing.postLogo(widget.timing.readyDelay);
    _animateProgressTo(1, duration);
    _schedule(duration + const Duration(milliseconds: 1), () {
      _readyDelayElapsed = true;
      _tryShowSystemReady();
    });
  }

  void _animateProgressTo(double target, Duration duration) {
    _progressController.animateTo(target, duration: duration);
  }

  void _onInitializationChanged() {
    final state = widget.initialization.value;
    _trace('initialization_changed');
    if (!widget.isInitialBootPresentation) return;
    if (state.mode == PersistenceMode.failed) {
      _invalidateSession('initialization_failed');
      _transition(BootPresentationState.failure, 'initialization_failed');
      if (mounted) {
        setState(() {});
      }
      _releasePresentation('failure_presentation_released');
      return;
    }
    if (state.mode == PersistenceMode.initializing) {
      if (_systemInitialized ||
          _presentation == BootPresentationState.bootHandoffSignal ||
          _presentation == BootPresentationState.mainUi) {
        _invalidateSession('reinitialization_begins');
        _transition(
          BootPresentationState.reinitializationLoading,
          'initialization_returned_to_loading',
        );
        if (mounted) setState(() {});
        _releasePresentation('reinitialization_presentation_released');
      }
      return;
    }
    if (_presentation == BootPresentationState.reinitializationLoading) {
      _transition(BootPresentationState.mainUi, 'reinitialization_ready');
      if (mounted) setState(() {});
      return;
    }
    if (_systemInitialized) {
      if (mounted && _presentation == BootPresentationState.mainUi) {
        setState(() {});
      }
      return;
    }
    _systemInitialized = true;
    _emit(BootSequenceEventType.systemInitialized);
    _tryStartFinalProgress();
  }

  void _tryShowSystemReady() {
    if (!_isPresentationActive ||
        !_systemInitialized ||
        !_readyDelayElapsed ||
        _phase != _BootVisualPhase.finalizing) {
      return;
    }
    setState(() => _phase = _BootVisualPhase.systemReady);
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'BOOT_PHASE_SYSTEM_READY',
      presentation: 'BOOT',
    );
    _transition(BootPresentationState.systemReadyPresentation, 'system_ready');
    _schedule(widget.timing.postLogo(widget.timing.readyHold), () {
      if (!_isPresentationActive || _skipRequested) return;
      _transition(
        BootPresentationState.bootHandoffSignal,
        'signal_handoff_started',
      );
      StartupDiagnostic.instance.record(
        'FLUTTER',
        'BOOT_PHASE_HANDOFF',
        presentation: 'BOOT',
      );
      setState(() {});
      _schedule(widget.timing.postLogo(_bootSignalHandoffDuration), () {
        if (_presentation != BootPresentationState.bootHandoffSignal) return;
        _transition(BootPresentationState.mainUi, 'signal_handoff_finished');
        StartupDiagnostic.instance.record(
          'FLUTTER',
          'BOOT_PHASE_MAIN_UI',
          presentation: 'MAIN_UI',
        );
        setState(() {});
        _emit(BootSequenceEventType.bootComplete);
        _releasePresentation('normal_boot_presentation_released');
      });
    });
  }

  void _requestSkip() {
    if (!_isPresentationActive || _skipRequested) return;
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'BOOT_SKIP_TAPPED',
      presentation: 'BOOT',
    );
    _skipRequested = true;
    _invalidateSession('boot_skip_requested');
    if (widget.initialization.value.mode == PersistenceMode.failed) {
      StartupDiagnostic.instance.record(
        'FLUTTER',
        'BOOT_SKIP_TARGET_FAILURE',
        presentation: 'FAILURE',
      );
      _transition(BootPresentationState.failure, 'skip_after_failure');
    } else if (_isInitializationReady) {
      StartupDiagnostic.instance.record(
        'FLUTTER',
        'BOOT_SKIP_TARGET_MAIN',
        presentation: 'MAIN_UI',
      );
      _transition(
        BootPresentationState.mainUi,
        'skip_with_initialization_ready',
      );
    } else {
      StartupDiagnostic.instance.record(
        'FLUTTER',
        'BOOT_SKIP_TARGET_INITIALIZING',
        presentation: 'INITIALIZING',
      );
      _transition(
        BootPresentationState.reinitializationLoading,
        'skip_waiting_for_initialization',
      );
    }
    if (mounted) setState(() {});
    _releasePresentation('skip_presentation_released');
  }

  void _releasePresentation(String event) {
    if (_presentationReleased) return;
    _presentationReleased = true;
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'BOOT_GATE_RELEASE_REQUEST',
      presentation: _diagnosticPresentation,
      fields: {'reason': event},
    );
    _trace(event);
    widget.onPresentationReleased?.call();
  }

  void _transition(BootPresentationState next, String event) {
    final previous = _presentation;
    _presentation = next;
    _trace(event, previous: previous);
  }

  void _trace(String event, {BootPresentationState? previous}) {
    final trace = BootStartupTraceEvent(
      occurredAt: DateTime.now(),
      event: event,
      previousState: previous ?? _presentation,
      nextState: _presentation,
      initializationMode: widget.initialization.value.mode,
      visualPhase: _phase.name,
      session: _session,
    );
    widget.onTrace?.call(trace);
    assert(() {
      debugPrint(trace.toString());
      return true;
    }());
  }

  void _emit(BootSequenceEventType type) {
    try {
      widget.onEvent?.call(
        BootSequenceEvent(type: type, occurredAt: DateTime.now()),
      );
    } catch (_) {
      // Future audio hooks must never block access to the application.
    }
  }

  @override
  Widget build(BuildContext context) {
    _recordDiagnosticBuild();
    final state = widget.initialization.value;
    if (state.mode == PersistenceMode.failed) {
      return widget.fallbackBuilder(state);
    }
    if (!widget.isInitialBootPresentation) {
      return ValueListenableBuilder<AppInitializationState>(
        valueListenable: widget.initialization,
        builder: (context, loadingState, _) =>
            widget.fallbackBuilder(loadingState),
      );
    }
    if (_presentation == BootPresentationState.reinitializationLoading) {
      return widget.fallbackBuilder(state);
    }
    if (_presentation == BootPresentationState.mainUi) return widget.child;
    if (_presentation == BootPresentationState.bootHandoffSignal) {
      return _BootSignalHandoff(
        duration: widget.timing.postLogo(_bootSignalHandoffDuration),
      );
    }
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, _) => _BootSequenceVisual(
        phase: _phase,
        typedLength: _typedLength,
        typedNameLength: _typedNameLength,
        typedAxisLength: _typedAxisLength,
        progress: _progressController.value,
        logoFadeDuration: widget.timing.logoIntro,
        signalAcquisitionIntroDuration: widget.timing.signalAcquisitionIntro,
        signalMode: widget.timing.signalMode,
        preBootSignalIntroDuration: widget.timing.preBootSignalIntro,
        waitForLogoDrawable: widget.timing.waitForLogoDrawable,
        onLogoFadeComplete: _startIdentityTypingAfterLogoFade,
        onSkip: _requestSkip,
      ),
    );
  }

  String get _diagnosticPresentation => switch (_presentation) {
    BootPresentationState.reinitializationLoading => 'INITIALIZING',
    BootPresentationState.mainUi => 'MAIN_UI',
    BootPresentationState.failure => 'FAILURE',
    _ => 'BOOT',
  };

  void _recordDiagnosticBuild() {
    final presentation = _diagnosticPresentation;
    if (_lastDiagnosticPresentation == presentation) return;
    _lastDiagnosticPresentation = presentation;
    StartupDiagnostic.instance.record(
      'FLUTTER',
      'BOOT_GATE_BUILD',
      state: widget.initialization.value.mode.name,
      presentation: presentation,
      fields: {
        'bootPresentationState': _presentation.name,
        'phase': _phase.name,
      },
    );
  }
}
