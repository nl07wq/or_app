import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/history_visual_preference.dart';

/// Deterministic, world-fixed DATA VAULT flight renderer.  It deliberately
/// owns only Ambient B geometry; HISTORY foreground UI remains outside it.
class HistoryDataVaultHyperspace {
  const HistoryDataVaultHyperspace({
    required this.seconds,
    this.impulseMode = DataVaultImpulseMode.hybrid,
  });

  final double seconds;
  final DataVaultImpulseMode impulseMode;

  static final _world = _VaultWorld();

  void paint(Canvas canvas, Size size) {
    final cameraDistance = HistoryDataVaultMotion.distanceAt(seconds);
    _world.prepare(cameraDistance + 94, retainFrom: cameraDistance - 12);
    final speed = HistoryDataVaultMotion.speedAt(seconds);
    final lookAhead = speed >= 9
        ? 13.0
        : speed >= 6
        ? 10.0
        : 8.0;
    final camera = _VaultCamera(
      position: _world.sample(cameraDistance),
      target: _world.sample(cameraDistance + lookAhead),
      distance: cameraDistance,
      curvature: _world.curvatureAt(cameraDistance + 10),
      size: size,
    );
    final samples = _surfaceSamples(cameraDistance);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff030a14),
    );
    _paintSurfaces(canvas, camera, samples);
    _paintFloorDetail(canvas, camera, samples);
    _paintPillars(canvas, camera, cameraDistance);
    // V2.3 is one production composition. The legacy mode value is retained
    // only for backwards-compatible construction in older test harnesses;
    // it never changes the shared flight world or its visible discharge mix.
    _paintDataTraffic(canvas, camera, cameraDistance);
    _paintCompositeSurfaceScans(canvas, camera, cameraDistance);
    _paintCompositeNodeDischarges(canvas, camera, cameraDistance);
    final guide = _resolveNavigationGuide(camera, cameraDistance, size, speed);
    if (guide != null) {
      _paintNavigationTrail(canvas, camera, cameraDistance, guide.sHead);
      _paintNavigationBeacon(canvas, guide, size);
    }
    canvas.restore();
  }

  List<_VaultSample> _surfaceSamples(double start) {
    final result = <_VaultSample>[];
    var s = start + .5;
    while (s <= start + 90 && result.length < 61) {
      final curvature = _world.curvatureAt(s).abs();
      result.add(_world.sample(s));
      s += curvature > .012 ? 1.5 : 3;
    }
    if (result.length < 2) result.add(_world.sample(start + 90));
    return result;
  }

  void _paintSurfaces(
    Canvas canvas,
    _VaultCamera camera,
    List<_VaultSample> samples,
  ) {
    for (var index = samples.length - 2; index >= 0; index--) {
      final far = samples[index + 1];
      final near = samples[index];
      final fog = ((far.s - camera.distance - 25) / 65).clamp(0.0, .75);
      _fillWorldQuad(
        canvas,
        camera,
        [
          near.point(-4, 0),
          near.point(4, 0),
          far.point(4, 0),
          far.point(-4, 0),
        ],
        Color.lerp(const Color(0xff0b2c48), const Color(0xff030a14), fog)!,
      );
      _fillWorldQuad(
        canvas,
        camera,
        [
          near.point(-4, 5),
          far.point(-4, 5),
          far.point(4, 5),
          near.point(4, 5),
        ],
        Color.lerp(const Color(0xff07192a), const Color(0xff030a14), fog)!,
      );
      _fillWorldQuad(
        canvas,
        camera,
        [
          near.point(-4, 0),
          far.point(-4, 0),
          far.point(-4, 5),
          near.point(-4, 5),
        ],
        Color.lerp(const Color(0xff0e314b), const Color(0xff030a14), fog)!,
      );
      _fillWorldQuad(
        canvas,
        camera,
        [near.point(4, 0), near.point(4, 5), far.point(4, 5), far.point(4, 0)],
        Color.lerp(const Color(0xff071627), const Color(0xff030a14), fog)!,
      );
    }
  }

  void _paintFloorDetail(
    Canvas canvas,
    _VaultCamera camera,
    List<_VaultSample> samples,
  ) {
    for (final offset in const [-3.2, -1.6, 0.0, 1.6, 3.2]) {
      _strokeWorldPolyline(
        canvas,
        camera,
        samples.map((sample) => sample.point(offset, 0)).toList(),
        const Color(0xff29bce4).withValues(alpha: .18),
        1,
      );
    }
    // These rails remain deliberately restrained; their moving packets are
    // painted later, after pillars, so they read as traffic through the same
    // projected corridor rather than a flat overlay.
    for (final side in [-1.0, 1.0]) {
      for (final height in [1.12, 3.72]) {
        _strokeWorldPolyline(
          canvas,
          camera,
          samples.map((sample) => sample.point(side * 3.94, height)).toList(),
          const Color(0xff42bce8).withValues(alpha: .105),
          .75,
        );
      }
    }
    for (final lateral in const [-2.0, 0.0, 2.0]) {
      _strokeWorldPolyline(
        canvas,
        camera,
        samples.map((sample) => sample.point(lateral, 4.88)).toList(),
        const Color(0xff64cdf0).withValues(alpha: .09),
        .65,
      );
    }
    final minSeam = ((camera.distance - 2) / 6).floor();
    for (var n = minSeam; n <= minSeam + 16; n++) {
      final sample = _world.sample(n * 6.0);
      _strokeWorldLine(
        canvas,
        camera,
        sample.point(-4, 0),
        sample.point(4, 0),
        const Color(0xff40b4df).withValues(alpha: .13),
        .8,
      );
    }
  }

  void _paintPillars(Canvas canvas, _VaultCamera camera, double distance) {
    final first = ((distance - 3) / 6).floor();
    final pillars = <_VaultSample>[];
    for (var n = first; n < first + 18; n++) {
      final s = n * 6.0;
      if (s > distance + 92) break;
      pillars.add(_world.sample(s));
    }
    for (final sample in pillars.reversed) {
      final n = (sample.s / 6).round();
      final accessResponse = HistoryDataVaultMotion.pillarAccessResponse(
        seconds,
        distance,
        sample.s,
      );
      final boostResponse = HistoryDataVaultMotion.boostStrengthAt(seconds);
      final brightness =
          .90 +
          .10 * math.sin(math.pi * 2 * seconds / 12 + n * .65) +
          accessResponse * (.34 + .12 * boostResponse);
      for (final side in [-1.0, 1.0]) {
        final depth = sample.s - distance;
        final alpha = (1 - depth / 110).clamp(.12, .90) * brightness;
        _pillarLayer(
          canvas,
          camera,
          sample,
          side,
          .55,
          const Color(0xff29bce4).withValues(alpha: .10 * alpha),
        );
        _pillarLayer(
          canvas,
          camera,
          sample,
          side,
          .18,
          const Color(0xff29bce4).withValues(alpha: .36 * alpha),
        );
        _pillarLayer(
          canvas,
          camera,
          sample,
          side,
          .045,
          const Color(0xff91f4ff).withValues(alpha: .82 * alpha),
        );
        _pillarEdge(canvas, camera, sample, side, alpha);
        if (depth > 2 && depth < 45) {
          _strokeWorldLine(
            canvas,
            camera,
            sample.point(side * 3.8, 0),
            sample
                .point(side * 3.8, 0)
                .translate(sample.tangentX * 1.7, sample.tangentZ * 1.7),
            const Color(0xff91f4ff).withValues(alpha: .12 * alpha),
            .8,
          );
        }
      }
    }
  }

  void _pillarLayer(
    Canvas canvas,
    _VaultCamera camera,
    _VaultSample sample,
    double side,
    double width,
    Color color,
  ) {
    _fillWorldQuad(canvas, camera, [
      sample.point(side * 3.8 - width / 2, 0),
      sample.point(side * 3.8 + width / 2, 0),
      sample.point(side * 3.8 + width / 2, 5),
      sample.point(side * 3.8 - width / 2, 5),
    ], color);
  }

  void _pillarEdge(
    Canvas canvas,
    _VaultCamera camera,
    _VaultSample sample,
    double side,
    double alpha,
  ) {
    _strokeWorldLine(
      canvas,
      camera,
      sample.point(side * 3.8 - .09, 0),
      sample.point(side * 3.8 - .09, 5),
      const Color(0xffc9fbff).withValues(alpha: .2 * alpha),
      .7,
    );
  }

  // ignore: unused_element
  void _paintArcTraffic(
    Canvas canvas,
    _VaultCamera camera,
    double distance,
    int cap,
  ) {
    var painted = 0;
    for (var lane = 0; lane < 7 && painted < cap; lane++) {
      final current = HistoryDataVaultMotion.arcEpisodeIndexAt(seconds, lane);
      for (
        var index = current;
        index >= current - 2 && painted < cap;
        index--
      ) {
        final event = HistoryDataVaultMotion.arcEpisodeFor(lane, index);
        if (!event.isActiveAt(seconds)) continue;
        if (_paintLocalArc(canvas, camera, distance, event)) painted++;
      }
    }
  }

  bool _paintLocalArc(
    Canvas canvas,
    _VaultCamera camera,
    double distance,
    DataVaultArcEpisode event, {
    double brightness = 1,
  }) {
    if (event.anchorS < distance - 4 || event.anchorS > distance + 92) {
      return false;
    }
    final endpoints = _arcEndpoints(event);
    final midpoint = _blendWorld(endpoints.$1, endpoints.$2, .5);
    final projected = camera.project(midpoint);
    if (projected == null) return false;
    final visibility = HistoryDataVaultMotion.impulseVisibility(projected.z);
    final envelope = event.brightnessAt(seconds) * visibility * brightness;
    if (envelope <= .01) return false;
    final points = <_WorldPoint>[endpoints.$1];
    final kinkCount =
        1 + (HistoryDataVaultMotion.seedUnit(event.seed + 3) * 3).floor();
    final dx = endpoints.$2.x - endpoints.$1.x;
    final dz = endpoints.$2.z - endpoints.$1.z;
    final horizontalLength = math.max(.001, math.sqrt(dx * dx + dz * dz));
    for (var index = 1; index <= kinkCount; index++) {
      final u = index / (kinkCount + 1);
      final base = _blendWorld(endpoints.$1, endpoints.$2, u);
      final jitter =
          (HistoryDataVaultMotion.seedUnit(event.seed + index * 37) - .5) * .16;
      points.add(
        _WorldPoint(
          base.x - dz / horizontalLength * jitter,
          base.y +
              (HistoryDataVaultMotion.seedUnit(event.seed + index * 53) - .5) *
                  .10,
          base.z + dx / horizontalLength * jitter,
        ),
      );
    }
    points.add(endpoints.$2);
    final tint = _arcColor(event.seed);
    for (final layer in [(4.1, .14), (2.0, .32), (.85, .90)]) {
      _strokeWorldPolyline(
        canvas,
        camera,
        points,
        (layer.$1 == .85 ? const Color(0xffddfbff) : tint).withValues(
          alpha: (layer.$2 * envelope).clamp(0, 1),
        ),
        layer.$1,
      );
    }
    if (event.hasBranch) {
      final start = points[points.length ~/ 2];
      final branch = _blendWorld(start, endpoints.$2, .25);
      _strokeWorldLine(
        canvas,
        camera,
        start,
        branch,
        tint.withValues(alpha: .26 * envelope),
        .65,
      );
    }
    return true;
  }

  (_WorldPoint, _WorldPoint) _arcEndpoints(DataVaultArcEpisode event) {
    final sample = _world.sample(event.anchorS);
    final side = HistoryDataVaultMotion.seedUnit(event.seed + 41) < .5
        ? -1.0
        : 1.0;
    return switch (event.family) {
      DataVaultArcFamily.leftWallFloor => (
        sample.point(
          -3.94,
          1.05 + HistoryDataVaultMotion.seedUnit(event.seed + 5) * 1.8,
        ),
        _world.sample(event.anchorS + .24).point(-3.38, .06),
      ),
      DataVaultArcFamily.rightWallCeiling => (
        sample.point(
          3.94,
          2.1 + HistoryDataVaultMotion.seedUnit(event.seed + 7) * 1.7,
        ),
        _world.sample(event.anchorS + .20).point(3.42, 4.88),
      ),
      DataVaultArcFamily.pillarWall => (
        sample.point(
          side * 3.8,
          1.2 + HistoryDataVaultMotion.seedUnit(event.seed + 11) * 2.8,
        ),
        _world
            .sample(event.anchorS + .18)
            .point(
              side * 3.95,
              1.45 + HistoryDataVaultMotion.seedUnit(event.seed + 13) * 2.5,
            ),
      ),
      DataVaultArcFamily.floorLocal => (
        sample.point(
          -2.8 + HistoryDataVaultMotion.seedUnit(event.seed + 17) * 5.6,
          .06,
        ),
        _world
            .sample(event.anchorS + .52)
            .point(
              -2.6 + HistoryDataVaultMotion.seedUnit(event.seed + 19) * 5.2,
              .08,
            ),
      ),
    };
  }

  _WorldPoint _blendWorld(_WorldPoint a, _WorldPoint b, double t) =>
      _WorldPoint(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.z + (b.z - a.z) * t,
      );

  Color _arcColor(int seed) => const [
    Color(0xff64e6f8),
    Color(0xff36bdeb),
    Color(0xffb8f4ff),
    Color(0xff6285ff),
  ][(HistoryDataVaultMotion.seedUnit(seed + 17) * 4).floor().clamp(0, 3)];

  // ignore: unused_element
  void _paintSurfaceScans(Canvas canvas, _VaultCamera camera, double distance) {
    const scans = <_DataVaultRail>[
      _DataVaultRail(DataVaultImpulseSurface.floor, 0, -1.6, .04),
      _DataVaultRail(DataVaultImpulseSurface.floor, 1, 1.45, .04),
      _DataVaultRail(DataVaultImpulseSurface.leftWall, 0, -3.95, 2.15),
      _DataVaultRail(DataVaultImpulseSurface.rightWall, 0, 3.95, 2.9),
      _DataVaultRail(DataVaultImpulseSurface.ceiling, 0, 0, 4.88),
    ];
    var gateVisible = false;
    for (final rail in scans) {
      final current = HistoryDataVaultMotion.scanEventIndexAt(
        seconds,
        rail.surface,
        rail.lane,
      );
      for (var index = current; index >= current - 2; index--) {
        final event = HistoryDataVaultMotion.scanEventFor(
          rail.surface,
          rail.lane,
          index,
        );
        if (!event.isActiveAt(seconds)) continue;
        final head = event.frontAt(seconds);
        if (head < distance - 5 || head > distance + 94) continue;
        final pattern = HistoryDataVaultMotion.scanPatternFor(event.seed);
        if (pattern == DataVaultScanPattern.gate && gateVisible) continue;
        switch (pattern) {
          case DataVaultScanPattern.surfaceSweep:
            _paintSurfaceSweep(canvas, camera, rail, event, head);
          case DataVaultScanPattern.gate:
            _paintGateScan(canvas, camera, event, head);
            gateVisible = true;
          case DataVaultScanPattern.stripRaster:
            _paintStripRaster(canvas, camera, rail, event, head);
        }
      }
    }
  }

  /// V2.3 schedules scans globally, rather than once per surface. This keeps
  /// them recognisable as occasional spatial probes instead of a second rail
  /// traffic system competing with SPARK.
  void _paintCompositeSurfaceScans(
    Canvas canvas,
    _VaultCamera camera,
    double distance,
  ) {
    var painted = 0;
    var gateVisible = false;
    final current = HistoryDataVaultMotion.compositeScanIndexAt(seconds);
    // Inspect a bounded third candidate as the 25%-denser cadence can leave
    // an older event in its fading, still-visible approach window.
    for (var index = current; index >= current - 2 && painted < 2; index--) {
      final event = HistoryDataVaultMotion.compositeScanEventFor(index);
      if (!event.isActiveAt(seconds)) continue;
      final head = event.frontAt(seconds);
      if (head < distance - 5 || head > distance + 94) continue;
      final rail = _compositeScanRail(event.seed);
      final pattern = HistoryDataVaultMotion.compositeScanPatternFor(
        event.seed,
      );
      if (pattern == DataVaultScanPattern.gate && gateVisible) continue;
      switch (pattern) {
        case DataVaultScanPattern.surfaceSweep:
          _paintSurfaceSweep(canvas, camera, rail, event, head);
        case DataVaultScanPattern.gate:
          _paintGateScan(canvas, camera, event, head);
          gateVisible = true;
        case DataVaultScanPattern.stripRaster:
          _paintStripRaster(canvas, camera, rail, event, head);
      }
      painted++;
    }
  }

  _DataVaultRail _compositeScanRail(int seed) {
    const rails = <_DataVaultRail>[
      _DataVaultRail(DataVaultImpulseSurface.floor, 0, -1.5, .04),
      _DataVaultRail(DataVaultImpulseSurface.floor, 1, 1.35, .04),
      _DataVaultRail(DataVaultImpulseSurface.leftWall, 0, -3.95, 2.15),
      _DataVaultRail(DataVaultImpulseSurface.rightWall, 0, 3.95, 2.9),
      _DataVaultRail(DataVaultImpulseSurface.ceiling, 0, 0, 4.88),
    ];
    return rails[(HistoryDataVaultMotion.seedUnit(seed + 43) * rails.length)
        .floor()];
  }

  void _paintSurfaceSweep(
    Canvas canvas,
    _VaultCamera camera,
    _DataVaultRail rail,
    DataVaultInboundEvent event,
    double head,
  ) {
    final width = rail.surface == DataVaultImpulseSurface.floor ? 2.15 : 1.35;
    final tail = head + event.length;
    _fillWorldQuad(canvas, camera, [
      _scanPoint(rail, head, -width),
      _scanPoint(rail, head, width),
      _scanPoint(rail, tail, width),
      _scanPoint(rail, tail, -width),
    ], const Color(0xff36bdeb).withValues(alpha: .11));
    for (final depthOffset in [0.0, .16, .36]) {
      for (var notch = 0; notch < 5; notch++) {
        final u = notch / 4;
        final cross = -width + width * 2 * u;
        _strokeWorldLine(
          canvas,
          camera,
          _scanPoint(rail, head + depthOffset, cross),
          _scanPoint(rail, head + depthOffset + .10, cross + .08),
          const Color(
            0xffddfbff,
          ).withValues(alpha: depthOffset == 0 ? .86 : .22),
          depthOffset == 0 ? .85 : .45,
        );
      }
    }
  }

  void _paintGateScan(
    Canvas canvas,
    _VaultCamera camera,
    DataVaultInboundEvent event,
    double head,
  ) {
    final points = <_WorldPoint>[
      _world.sample(head).point(-3.92, .30),
      _world.sample(head).point(-3.92, 4.78),
      _world.sample(head).point(3.92, 4.78),
      _world.sample(head).point(3.92, .30),
    ];
    for (final layer in [(3.0, .08), (1.4, .22), (.72, .76)]) {
      _strokeWorldPolyline(
        canvas,
        camera,
        points,
        const Color(0xff9aeeff).withValues(alpha: layer.$2),
        layer.$1,
      );
    }
    if (HistoryDataVaultMotion.seedUnit(event.seed + 71) < .45) {
      final sample = _world.sample(head + .48);
      final delayed = <_WorldPoint>[
        sample.point(-3.86, .30),
        sample.point(-3.86, 4.78),
        sample.point(3.86, 4.78),
        sample.point(3.86, .30),
      ];
      _strokeWorldPolyline(
        canvas,
        camera,
        delayed,
        const Color(0xff64e6f8).withValues(alpha: .16),
        .65,
      );
    }
  }

  void _paintStripRaster(
    Canvas canvas,
    _VaultCamera camera,
    _DataVaultRail rail,
    DataVaultInboundEvent event,
    double head,
  ) {
    final count =
        4 + (HistoryDataVaultMotion.seedUnit(event.seed + 31) * 5).floor();
    final span = rail.surface == DataVaultImpulseSurface.floor ? 2.7 : 1.85;
    for (var stripe = 0; stripe < count; stripe++) {
      final u = count == 1 ? .5 : stripe / (count - 1);
      final cross = -span + span * 2 * u;
      final length =
          .25 + HistoryDataVaultMotion.seedUnit(event.seed + stripe * 17) * .60;
      final delay = stripe * .035;
      _strokeWorldLine(
        canvas,
        camera,
        _scanPoint(rail, head + delay, cross),
        _scanPoint(
          rail,
          head + delay + length,
          cross + (stripe.isEven ? .05 : -.05),
        ),
        const Color(0xffb8f4ff).withValues(alpha: .48 + .24 * (stripe % 2)),
        .75,
      );
    }
  }

  _WorldPoint _scanPoint(_DataVaultRail rail, double s, double cross) {
    return switch (rail.surface) {
      DataVaultImpulseSurface.floor || DataVaultImpulseSurface.ceiling =>
        _world.sample(s).point(rail.lateral + cross, rail.height),
      DataVaultImpulseSurface.leftWall || DataVaultImpulseSurface.rightWall =>
        _world
            .sample(s)
            .point(rail.lateral, (rail.height + cross).clamp(.05, 4.88)),
    };
  }

  // ignore: unused_element
  void _paintNodeDischarges(
    Canvas canvas,
    _VaultCamera camera,
    double distance,
  ) {
    var painted = 0;
    for (var track = 0; track < 5 && painted < 4; track++) {
      final current = HistoryDataVaultMotion.nodeEventIndexAt(seconds, track);
      for (var index = current; index >= current - 2 && painted < 4; index--) {
        final event = HistoryDataVaultMotion.nodeEventFor(track, index);
        final hop = event.activeHopAt(seconds);
        if (hop == null ||
            event.anchorS < distance - 4 ||
            event.anchorS > distance + 92) {
          continue;
        }
        _paintNodeHop(canvas, camera, event, hop);
        painted++;
      }
    }
  }

  /// Rare global node cascades make the installation respond to traffic
  /// without creating the old dense side-wall chart of simultaneous links.
  void _paintCompositeNodeDischarges(
    Canvas canvas,
    _VaultCamera camera,
    double distance,
  ) {
    final current = HistoryDataVaultMotion.compositeNodeIndexAt(seconds);
    for (var index = current; index >= current - 1; index--) {
      final event = HistoryDataVaultMotion.compositeNodeEventFor(index);
      if (!event.isActiveAt(seconds) ||
          event.anchorS < distance - 4 ||
          event.anchorS > distance + 92) {
        continue;
      }
      final active = event.activeHopsAt(seconds);
      for (final hop in active.take(3)) {
        _paintNodeHop(canvas, camera, event, hop, brightness: .74);
      }
      return;
    }
  }

  void _paintNodeHop(
    Canvas canvas,
    _VaultCamera camera,
    DataVaultNodeEvent event,
    int hop, {
    double brightness = 1,
  }) {
    final link = event.links[hop];
    final anchors = event.anchors;
    final from = _nodePoint(anchors[link.from], event.anchorS, event.seed);
    final to = _nodePoint(
      anchors[link.to],
      event.anchorS + link.depthOffset,
      event.seed + 19,
    );
    final points = <_WorldPoint>[from];
    final segmentCount =
        1 +
        (HistoryDataVaultMotion.seedUnit(event.seed + hop * 29) * 2).floor();
    for (var index = 1; index <= segmentCount; index++) {
      final base = _blendWorld(from, to, index / (segmentCount + 1));
      final jitter =
          (HistoryDataVaultMotion.seedUnit(event.seed + hop * 43 + index * 11) -
              .5) *
          .18;
      points.add(
        _WorldPoint(
          base.x + jitter,
          base.y - jitter * .42,
          base.z + jitter * .35,
        ),
      );
    }
    points.add(to);
    final phase = event.hopBrightnessAt(seconds, hop) * brightness;
    for (final layer in [(3.6, .11), (1.8, .27), (.82, .86)]) {
      _strokeWorldPolyline(
        canvas,
        camera,
        points,
        (layer.$1 == .82 ? const Color(0xffddfbff) : const Color(0xff64e6f8))
            .withValues(alpha: layer.$2 * phase),
        layer.$1,
      );
    }
    for (final node in [from, to]) {
      final projected = camera.project(node);
      if (projected == null) continue;
      canvas.drawCircle(
        projected.offset,
        2.6,
        Paint()..color = const Color(0xff36bdeb).withValues(alpha: .16 * phase),
      );
      canvas.drawCircle(
        projected.offset,
        .85,
        Paint()..color = const Color(0xffddfbff).withValues(alpha: .82 * phase),
      );
    }
  }

  _WorldPoint _nodePoint(DataVaultNodeAnchor anchor, double s, int seed) {
    final sample = _world.sample(s);
    final side = HistoryDataVaultMotion.seedUnit(seed + anchor.index * 13) < .5
        ? -1.0
        : 1.0;
    return switch (anchor) {
      DataVaultNodeAnchor.leftWallLow => sample.point(-3.94, 1.05),
      DataVaultNodeAnchor.leftWallHigh => sample.point(-3.94, 3.85),
      DataVaultNodeAnchor.rightWallLow => sample.point(3.94, 1.18),
      DataVaultNodeAnchor.rightWallHigh => sample.point(3.94, 3.78),
      DataVaultNodeAnchor.floorLeft => sample.point(-2.45, .05),
      DataVaultNodeAnchor.floorCenter => sample.point(0, .05),
      DataVaultNodeAnchor.floorRight => sample.point(2.45, .05),
      DataVaultNodeAnchor.ceilingLeft => sample.point(-2.25, 4.88),
      DataVaultNodeAnchor.ceilingCenter => sample.point(0, 4.88),
      DataVaultNodeAnchor.ceilingRight => sample.point(2.25, 4.88),
      DataVaultNodeAnchor.pillarLower => sample.point(side * 3.8, 1.05),
      DataVaultNodeAnchor.pillarMid => sample.point(side * 3.8, 2.55),
      DataVaultNodeAnchor.pillarUpper => sample.point(side * 3.8, 4.18),
    };
  }

  /// Renders incoming line impulses bound to the physical corridor rails.
  /// They flow from the distant aperture toward the viewer while the route
  /// beacon remains the sole representation of the viewer's own position.
  void _paintDataTraffic(
    Canvas canvas,
    _VaultCamera camera,
    double cameraDistance, {
    int? maxRails,
  }) {
    // Each rail owns an independent deterministic launch schedule.  This
    // deliberately prevents the old lattice's symmetric bundles from moving
    // as a set while retaining stable Golden output and physical projection.
    const rails = <_DataVaultRail>[
      _DataVaultRail(DataVaultImpulseSurface.floor, 0, -3.2, .035),
      _DataVaultRail(DataVaultImpulseSurface.floor, 1, -1.6, .035),
      _DataVaultRail(DataVaultImpulseSurface.floor, 2, 0, .035),
      _DataVaultRail(DataVaultImpulseSurface.floor, 3, 1.6, .035),
      _DataVaultRail(DataVaultImpulseSurface.floor, 4, 3.2, .035),
      _DataVaultRail(DataVaultImpulseSurface.leftWall, 0, -3.94, 1.12),
      _DataVaultRail(DataVaultImpulseSurface.leftWall, 1, -3.94, 3.72),
      _DataVaultRail(DataVaultImpulseSurface.rightWall, 0, 3.94, 1.12),
      _DataVaultRail(DataVaultImpulseSurface.rightWall, 1, 3.94, 3.72),
      _DataVaultRail(DataVaultImpulseSurface.ceiling, 0, -2, 4.88),
      _DataVaultRail(DataVaultImpulseSurface.ceiling, 1, 0, 4.88),
      _DataVaultRail(DataVaultImpulseSurface.ceiling, 2, 2, 4.88),
    ];
    for (var index = 0; index < rails.length; index++) {
      if (maxRails != null && index >= maxRails) break;
      final rail = rails[index];
      _paintScheduledRailImpulses(
        canvas,
        camera,
        cameraDistance,
        rail: rail,
        lane: rail.lane,
      );
    }
  }

  // Hybrid deliberately reuses the unchanged SPARK packet painter, but takes
  // a balanced subset instead of the old first-four (floor-only) rails.
  // ignore: unused_element
  void _paintHybridSparkTraffic(
    Canvas canvas,
    _VaultCamera camera,
    double cameraDistance,
  ) {
    const rails = <_DataVaultRail>[
      _DataVaultRail(DataVaultImpulseSurface.floor, 0, -3.2, .035),
      _DataVaultRail(DataVaultImpulseSurface.floor, 3, 1.6, .035),
      _DataVaultRail(DataVaultImpulseSurface.leftWall, 0, -3.94, 1.12),
      _DataVaultRail(DataVaultImpulseSurface.rightWall, 1, 3.94, 3.72),
      _DataVaultRail(DataVaultImpulseSurface.ceiling, 1, 0, 4.88),
    ];
    for (final rail in rails) {
      _paintScheduledRailImpulses(
        canvas,
        camera,
        cameraDistance,
        rail: rail,
        lane: rail.lane,
      );
    }
  }

  // ignore: unused_element
  void _paintHybridArcResponses(
    Canvas canvas,
    _VaultCamera camera,
    double distance,
  ) {
    var painted = 0;
    const rails = <_DataVaultRail>[
      _DataVaultRail(DataVaultImpulseSurface.floor, 0, -3.2, .035),
      _DataVaultRail(DataVaultImpulseSurface.floor, 3, 1.6, .035),
      _DataVaultRail(DataVaultImpulseSurface.leftWall, 0, -3.94, 1.12),
      _DataVaultRail(DataVaultImpulseSurface.rightWall, 1, 3.94, 3.72),
      _DataVaultRail(DataVaultImpulseSurface.ceiling, 1, 0, 4.88),
    ];
    for (final rail in rails) {
      if (painted >= 3) break;
      final profile = HistoryDataVaultMotion.impulseProfileFor(
        rail.surface,
        rail.lane,
      );
      final current =
          ((seconds - profile.launchOffset) / profile.repeatInterval).floor();
      for (
        var packet = current;
        packet >= current - 2 && painted < 3;
        packet--
      ) {
        final response = HistoryDataVaultMotion.hybridResponseFor(
          rail.surface,
          rail.lane,
          packet,
        );
        if (response == null || !response.isActiveAt(seconds)) continue;
        if (_paintLocalArc(
          canvas,
          camera,
          distance,
          response,
          brightness: .72,
        )) {
          painted++;
        }
      }
    }
  }

  void _paintScheduledRailImpulses(
    Canvas canvas,
    _VaultCamera camera,
    double cameraDistance, {
    required _DataVaultRail rail,
    required int lane,
  }) {
    final profile = HistoryDataVaultMotion.impulseProfileFor(
      rail.surface,
      lane,
    );
    // A lane can show one impulse normally and two during a boost.  Every
    // event still owns its own launch schedule, so boosts enrich density
    // without ever creating a synchronous surface-wide burst.
    final event = ((seconds - profile.launchOffset) / profile.repeatInterval)
        .floor();
    final boost = HistoryDataVaultMotion.boostStrengthAt(seconds);
    var painted = 0;
    final maximum = boost > .12 ? 3 : 2;
    for (var index = event; index >= event - 3 && painted < maximum; index--) {
      // A deterministic event-level decision preserves a retained packet for
      // its entire lifetime; it never flickers a live packet away.
      if (!HistoryDataVaultMotion.retainSparkPacket(
        rail.surface,
        rail.lane,
        index,
      )) {
        continue;
      }
      final launch = profile.launchOffset + index * profile.repeatInterval;
      final elapsed = seconds - launch;
      if (elapsed < 0 || elapsed > profile.visibleDuration) continue;
      final headS = HistoryDataVaultMotion.impulseHeadDistance(
        seconds: seconds,
        launchSeconds: launch,
        speedMultiplier: profile.speedMultiplier,
      );
      if (_paintPacketTrail(
        canvas,
        camera,
        headS,
        rail: rail,
        packetIndex: index,
        tailLength: profile.tailLength * (1 + .22 * boost),
        headLength: profile.headLength * (1 + .18 * boost),
        brightness: profile.brightness * (1 + .18 * boost),
        surface: rail.surface,
      )) {
        painted++;
      }
    }
  }

  bool _paintPacketTrail(
    Canvas canvas,
    _VaultCamera camera,
    double headS, {
    required _DataVaultRail rail,
    required int packetIndex,
    required double tailLength,
    required double headLength,
    required double brightness,
    required DataVaultImpulseSurface surface,
  }) {
    if (headS < camera.distance - 8 || headS > camera.distance + 92) {
      return false;
    }
    final headLateral = _packetLateral(rail, packetIndex, headS);
    final projectedHead = camera.project(
      _world.sample(headS).point(headLateral, rail.height),
    );
    if (projectedHead == null) return false;
    final visibility = HistoryDataVaultMotion.impulseVisibility(
      projectedHead.z,
    );
    if (visibility <= 0) return false;
    final variant = HistoryDataVaultMotion.impulseVariantFor(
      surface,
      rail.lane,
      packetIndex,
    );
    final material = _DataVaultImpulseMaterial.forSurface(surface, variant);
    tailLength *= variant.tailMultiplier;
    headLength *= switch (variant.family) {
      DataVaultImpulseFamily.shortPacket => .78,
      DataVaultImpulseFamily.mediumPacket => 1.0,
      DataVaultImpulseFamily.longBurst => 1.26,
    };
    brightness *= variant.brightnessMultiplier;
    final points = <_WorldPoint>[];
    // The packet head travels from aperture to viewer. Its fading tail is
    // therefore further away (positive arc length), never an approaching
    // round node or a free-floating 2D curve.
    for (var tail = tailLength; tail >= 0; tail -= .65) {
      final s = headS + tail;
      points.add(
        _world
            .sample(s)
            .point(_packetLateral(rail, packetIndex, s), rail.height),
      );
    }
    for (var layer = 0; layer < material.widths.length; layer++) {
      _strokeWorldPolyline(
        canvas,
        camera,
        points,
        (layer == material.widths.length - 1
                ? const Color(0xffd9fbff)
                : material.color)
            .withValues(
              alpha: material.alphas[layer] * brightness * visibility,
            ),
        material.widths[layer],
      );
    }
    _strokeWorldLine(
      canvas,
      camera,
      _world
          .sample(headS - headLength * .35)
          .point(
            _packetLateral(rail, packetIndex, headS - headLength * .35),
            rail.height,
          ),
      _world
          .sample(headS + headLength * .65)
          .point(
            _packetLateral(rail, packetIndex, headS + headLength * .65),
            rail.height,
          ),
      material.core.withValues(alpha: .88 * brightness * visibility),
      material.widths.last,
    );
    return true;
  }

  /// Floor traffic is intentionally independent from the five decorative
  /// floor rails.  Its seeded lateral anchor and mild world-space drift make
  /// transmission paths cross the grid without sacrificing corridor depth.
  double _packetLateral(_DataVaultRail rail, int packetIndex, double s) {
    if (rail.surface != DataVaultImpulseSurface.floor) return rail.lateral;
    return HistoryDataVaultMotion.floorImpulseLateralAt(
      rail.lane,
      packetIndex,
      s,
    );
  }

  _NavigationGuide? _resolveNavigationGuide(
    _VaultCamera camera,
    double cameraDistance,
    Size size,
    double speed,
  ) {
    final sprintAdvance = HistoryDataVaultMotion.beaconSprintAdvance(
      speed,
      seconds,
    );
    for (final factor in const [1.0, .88, 1.12]) {
      final sHead =
          cameraDistance +
          (HistoryDataVaultMotion.navigationHeadOffset + sprintAdvance) *
              factor;
      final projected = camera.project(_world.sample(sHead).point(0, .14));
      if (projected == null) continue;
      if (projected.offset.dx >= 0 &&
          projected.offset.dx <= size.width &&
          projected.offset.dy >= 0 &&
          projected.offset.dy <= size.height) {
        return _NavigationGuide(sHead, projected);
      }
    }
    return null;
  }

  void _paintNavigationTrail(
    Canvas canvas,
    _VaultCamera camera,
    double cameraDistance,
    double sHead,
  ) {
    final boost = HistoryDataVaultMotion.boostStrengthAt(seconds);
    final start =
        cameraDistance +
        HistoryDataVaultMotion.navigationTrailOffset -
        .8 * boost;
    final span = sHead - start;
    if (span <= 0) return;
    final points = <_WorldPoint>[];
    for (var s = start; s <= sHead; s += .45) {
      points.add(_world.sample(s).point(0, .11));
    }
    if (points.isEmpty || (sHead - start).remainder(.45).abs() > .001) {
      points.add(_world.sample(sHead).point(0, .11));
    }
    for (var index = 0; index < points.length - 1; index++) {
      final u = index / math.max(1, points.length - 2);
      final fade = .18 + .82 * u * u;
      final headGlow = .08 * boost * u * u;
      _strokeWorldLine(
        canvas,
        camera,
        points[index],
        points[index + 1],
        const Color(0xff36c9f3).withValues(alpha: (.09 + headGlow) * fade),
        6.5 + .65 * boost,
      );
      _strokeWorldLine(
        canvas,
        camera,
        points[index],
        points[index + 1],
        const Color(0xff5ae5ff).withValues(alpha: (.28 + headGlow) * fade),
        3 + .3 * boost,
      );
      _strokeWorldLine(
        canvas,
        camera,
        points[index],
        points[index + 1],
        const Color(0xffe8fdff).withValues(alpha: (.70 + headGlow) * fade),
        1.35,
      );
      if (u >= .75) {
        _strokeWorldLine(
          canvas,
          camera,
          points[index],
          points[index + 1],
          const Color(0xffe8fdff).withValues(alpha: .80 * fade),
          .7,
        );
      }
    }
  }

  void _paintNavigationBeacon(
    Canvas canvas,
    _NavigationGuide guide,
    Size size,
  ) {
    final scale =
        (size.width / 390).clamp(.85, 1.15) *
        (9 / guide.projected.z).clamp(.75, 1.25);
    final center = guide.projected.offset;
    final pulse = HistoryDataVaultMotion.beaconPulseAt(seconds);
    final boost = HistoryDataVaultMotion.boostStrengthAt(seconds);
    final outerRadius = (30 * pulse.outerRadius + boost * 2) * scale;
    final midRadius = (19 * (0.94 + .10 * pulse.breath) + boost) * scale;
    final coreRadius = (8.5 + boost * 1.5) * scale;
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..color = const Color(
          0xff2ac8f0,
        ).withValues(alpha: .13 * pulse.outerAlpha + .10 * boost),
    );
    canvas.drawCircle(
      center,
      midRadius,
      Paint()
        ..color = const Color(
          0xff70e8ff,
        ).withValues(alpha: .22 * pulse.midAlpha + .06 * boost),
    );
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..color = const Color(0xffd9fbff).withValues(
          alpha: (.83 * pulse.coreAlpha + .08 * boost).clamp(.0, 1.0),
        ),
    );
    canvas.drawCircle(
      center,
      2.5 * scale,
      Paint()..color = const Color(0xfff0ffff).withValues(alpha: .97),
    );
  }

  void _fillWorldQuad(
    Canvas canvas,
    _VaultCamera camera,
    List<_WorldPoint> points,
    Color color,
  ) {
    final clipped = camera.clip(points);
    if (clipped.length < 3) return;
    final projected = clipped
        .map(camera.projectCamera)
        .whereType<_Projected>()
        .toList();
    if (projected.length < 3) return;
    final path = Path()
      ..moveTo(projected.first.offset.dx, projected.first.offset.dy);
    for (final point in projected.skip(1)) {
      path.lineTo(point.offset.dx, point.offset.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _strokeWorldLine(
    Canvas canvas,
    _VaultCamera camera,
    _WorldPoint a,
    _WorldPoint b,
    Color color,
    double width,
  ) {
    final clipped = camera.clip([a, b]);
    if (clipped.length != 2) return;
    final start = camera.projectCamera(clipped[0]);
    final end = camera.projectCamera(clipped[1]);
    if (start == null || end == null) return;
    canvas.drawLine(
      start.offset,
      end.offset,
      Paint()
        ..color = color
        ..strokeWidth = width,
    );
  }

  void _strokeWorldPolyline(
    Canvas canvas,
    _VaultCamera camera,
    List<_WorldPoint> points,
    Color color,
    double width,
  ) {
    for (var index = 0; index < points.length - 1; index++) {
      _strokeWorldLine(
        canvas,
        camera,
        points[index],
        points[index + 1],
        color,
        width,
      );
    }
  }
}

class _NavigationGuide {
  const _NavigationGuide(this.sHead, this.projected);

  final double sHead;
  final _Projected projected;
}

/// Physical surface a DATA VAULT communication rail belongs to.  Values are
/// public so timing tests can validate the same independent schedules used by
/// the painter without coupling to its private render objects.
enum DataVaultImpulseSurface { floor, leftWall, rightWall, ceiling }

class DataVaultImpulseProfile {
  const DataVaultImpulseProfile({
    required this.launchOffset,
    required this.repeatInterval,
    required this.speedMultiplier,
    required this.visibleDuration,
    required this.headLength,
    required this.tailLength,
    required this.brightness,
  });

  final double launchOffset;
  final double repeatInterval;
  final double speedMultiplier;
  final double visibleDuration;
  final double headLength;
  final double tailLength;
  final double brightness;
}

/// A world-space event whose front is independent of the current camera
/// position.  Its route coordinate always decreases while it is active, so
/// the corridor receives a true far-to-near impulse rather than a screen-space
/// reversal or a camera-attached decoration.
class DataVaultInboundEvent {
  const DataVaultInboundEvent({
    required this.id,
    required this.seed,
    required this.launchSeconds,
    required this.travelMultiplier,
    required this.length,
    required this.lifetime,
    this.lead = 98,
  });

  final int id;
  final int seed;
  final double launchSeconds, travelMultiplier, length, lifetime, lead;

  double frontAt(double seconds) {
    final launchDistance = HistoryDataVaultMotion.distanceAt(launchSeconds);
    return launchDistance +
        lead -
        travelMultiplier *
            (HistoryDataVaultMotion.distanceAt(seconds) - launchDistance);
  }

  bool isActiveAt(double seconds) =>
      seconds >= launchSeconds && seconds <= launchSeconds + lifetime;
}

/// A short local electrical failure at fixed world anchors.  Unlike an
/// inbound packet it deliberately has no travelling head: its identity is a
/// brief discharge at a stable location in the corridor.
enum DataVaultArcFamily {
  leftWallFloor,
  rightWallCeiling,
  pillarWall,
  floorLocal,
}

class DataVaultArcEpisode {
  const DataVaultArcEpisode({
    required this.id,
    required this.seed,
    required this.launchSeconds,
    required this.lifetime,
    required this.anchorS,
    required this.family,
  });

  final int id, seed;
  final double launchSeconds, lifetime, anchorS;
  final DataVaultArcFamily family;

  bool isActiveAt(double seconds) =>
      seconds >= launchSeconds && seconds <= launchSeconds + lifetime;

  bool get hasBranch => HistoryDataVaultMotion.seedUnit(seed + 91) < .20;

  double brightnessAt(double seconds) {
    final u = ((seconds - launchSeconds) / lifetime).clamp(0.0, 1.0);
    final ignition = (u / .14).clamp(0.0, 1.0);
    final fade = ((1 - u) / .62).clamp(0.0, 1.0);
    final flicker = .92 + .08 * math.sin(seed * .017 + u * math.pi * 3);
    return math.min(ignition, fade) * flicker;
  }
}

enum DataVaultScanPattern { surfaceSweep, gate, stripRaster }

enum DataVaultNodeTopology { singleHop, relay, fork, converge }

enum DataVaultNodeAnchor {
  leftWallLow,
  leftWallHigh,
  rightWallLow,
  rightWallHigh,
  floorLeft,
  floorCenter,
  floorRight,
  ceilingLeft,
  ceilingCenter,
  ceilingRight,
  pillarLower,
  pillarMid,
  pillarUpper,
}

class DataVaultNodeLink {
  const DataVaultNodeLink(
    this.from,
    this.to,
    this.startOffset, {
    this.depthOffset = 0,
  });

  final int from, to;
  final double startOffset, depthOffset;
}

class DataVaultNodeEvent {
  const DataVaultNodeEvent({
    required this.id,
    required this.seed,
    required this.launchSeconds,
    required this.duration,
    required this.anchorS,
    required this.topology,
    required this.anchors,
    required this.links,
  });

  final int id, seed;
  final double launchSeconds, duration, anchorS;
  final DataVaultNodeTopology topology;
  final List<DataVaultNodeAnchor> anchors;
  final List<DataVaultNodeLink> links;

  bool isActiveAt(double seconds) =>
      seconds >= launchSeconds && seconds <= launchSeconds + duration;

  int? activeHopAt(double seconds) {
    final active = activeHopsAt(seconds);
    return active.isEmpty ? null : active.first;
  }

  List<int> activeHopsAt(double seconds) {
    final elapsed = seconds - launchSeconds;
    return [
      for (var index = 0; index < links.length; index++)
        if (elapsed >= links[index].startOffset &&
            elapsed <= links[index].startOffset + .18)
          index,
    ];
  }

  double hopBrightnessAt(double seconds, int hop) {
    final u = ((seconds - launchSeconds - links[hop].startOffset) / .18).clamp(
      0.0,
      1.0,
    );
    return math.sin(math.pi * u).clamp(0.0, 1.0);
  }
}

class DataVaultNodeCascade extends DataVaultInboundEvent {
  const DataVaultNodeCascade({
    required super.id,
    required super.seed,
    required super.launchSeconds,
    required super.travelMultiplier,
  }) : super(length: 3.6, lifetime: .62, lead: 80);

  int? activeHopAt(double seconds) {
    final elapsed = seconds - launchSeconds;
    for (var hop = 0; hop < 4; hop++) {
      final start = hop * .11;
      if (elapsed >= start && elapsed <= start + .18) return hop;
    }
    return null;
  }
}

class _DataVaultRail {
  const _DataVaultRail(this.surface, this.lane, this.lateral, this.height);

  final DataVaultImpulseSurface surface;
  final int lane;
  final double lateral;
  final double height;
}

enum DataVaultImpulseFamily { shortPacket, mediumPacket, longBurst }

class DataVaultImpulseVariant {
  const DataVaultImpulseVariant({
    required this.family,
    required this.colorIndex,
    required this.tailMultiplier,
    required this.brightnessMultiplier,
  });

  final DataVaultImpulseFamily family;
  final int colorIndex;
  final double tailMultiplier;
  final double brightnessMultiplier;
}

class DataVaultBeaconPulse {
  const DataVaultBeaconPulse({
    required this.breath,
    required this.outerRadius,
    required this.outerAlpha,
    required this.midAlpha,
    required this.coreAlpha,
  });

  final double breath;
  final double outerRadius, outerAlpha, midAlpha, coreAlpha;
}

class _DataVaultImpulseMaterial {
  const _DataVaultImpulseMaterial(
    this.color,
    this.core,
    this.widths,
    this.alphas,
  );

  final Color color;
  final Color core;
  final List<double> widths;
  final List<double> alphas;

  factory _DataVaultImpulseMaterial.forSurface(
    DataVaultImpulseSurface surface,
    DataVaultImpulseVariant variant,
  ) {
    const colors = [
      Color(0xff5ae5ff),
      Color(0xff51c9ef),
      Color(0xffb8f4ff),
      Color(0xff93b9ff),
    ];
    final tint = colors[variant.colorIndex];
    return switch (surface) {
      DataVaultImpulseSurface.floor => const _DataVaultImpulseMaterial(
        Color(0xff5ae5ff),
        Color(0xffd9fbff),
        [3.8, 2.0, .85],
        [.11, .30, .84],
      ),
      DataVaultImpulseSurface.leftWall ||
      DataVaultImpulseSurface.rightWall => const _DataVaultImpulseMaterial(
        Color(0xff51c9ef),
        Color(0xffd9fbff),
        [2.8, 1.4, .65],
        [.09, .27, .70],
      ),
      DataVaultImpulseSurface.ceiling => const _DataVaultImpulseMaterial(
        Color(0xff76dcff),
        Color(0xffd9fbff),
        [2.3, 1.15, .55],
        [.08, .23, .62],
      ),
    }._tinted(tint);
  }

  _DataVaultImpulseMaterial _tinted(Color tint) => _DataVaultImpulseMaterial(
    Color.lerp(color, tint, .62)!,
    Color.lerp(core, tint, .24)!,
    widths,
    alphas,
  );
}

class HistoryDataVaultMotion {
  static const cycleSeconds = 48.0;
  static const _speedMultiplier = 2.025;
  static const navigationHeadOffset = 5.5;
  static const navigationTrailOffset = 1.2;
  static const _distanceStep = .01;
  static final List<double> _distanceTable = _buildDistanceTable();
  static final double distancePerCycle = _distanceTable.last;

  static const _boostWindows = <(double start, double duration, double peak)>[
    (7.7, 1.9, 1.70),
    (18.4, 2.2, 1.82),
    (29.5, 1.8, 1.64),
    (43.1, 2.1, 1.76),
  ];

  /// Stable pseudo-random lane configuration.  The sequence is intentionally
  /// derived once from surface/lane identity rather than randomised per frame:
  /// independent launches remain reproducible for Goldens and never form
  /// mirrored or same-phase surface bundles.
  static DataVaultImpulseProfile impulseProfileFor(
    DataVaultImpulseSurface surface,
    int lane,
  ) {
    final seed = _impulseSeed(surface.index * 97 + lane * 31 + 17);
    final offset = _unit(seed) * 3.3;
    final interval = 1.1 + _unit(_impulseSeed(seed + 11)) * 2.6;
    final speed = .85 + _unit(_impulseSeed(seed + 29)) * .40;
    final surfaceTail = switch (surface) {
      DataVaultImpulseSurface.floor => 6.0,
      DataVaultImpulseSurface.leftWall ||
      DataVaultImpulseSurface.rightWall => 4.0,
      DataVaultImpulseSurface.ceiling => 3.0,
    };
    return DataVaultImpulseProfile(
      launchOffset: offset,
      repeatInterval: interval,
      speedMultiplier: speed,
      // Events begin fully faded at the aperture and finish behind the near
      // plane. This upper bound only limits reconstruction, not movement.
      visibleDuration: 5.2 + _unit(_impulseSeed(seed + 47)) * 1.1,
      headLength: .30 + _unit(_impulseSeed(seed + 61)) * .34,
      tailLength: surfaceTail + _unit(_impulseSeed(seed + 73)) * 1.4,
      brightness: .82 + _unit(_impulseSeed(seed + 89)) * .20,
    );
  }

  static int _impulseSeed(int value) {
    var x = value & 0x7fffffff;
    x = (x ^ (x << 13)) & 0x7fffffff;
    x = (x ^ (x >> 17)) & 0x7fffffff;
    return (x ^ (x << 5)) & 0x7fffffff;
  }

  static double _unit(int value) => (value & 0xffff) / 0xffff;

  /// Stable helpers shared by the painter and focused motion tests. They are
  /// deliberately independent of frame order, so no Golden frame flickers.
  static int packetSeed(
    DataVaultImpulseSurface surface,
    int lane,
    int packet,
  ) => _impulseSeed(surface.index * 12289 + lane * 313 + packet * 7919 + 41);

  static double seedUnit(int value) => _unit(_impulseSeed(value));

  static DataVaultArcEpisode arcEpisodeFor(int lane, int event) {
    final railSeed = _impulseSeed(lane * 479 + 31);
    final seed = _impulseSeed(railSeed + event * 421);
    final interval = 1.05 + seedUnit(railSeed + 7) * 1.18;
    return DataVaultArcEpisode(
      id: event,
      seed: seed,
      launchSeconds: seedUnit(railSeed + 11) * interval + event * interval,
      lifetime: .18 + seedUnit(seed + 17) * .24,
      anchorS:
          distanceAt(seedUnit(railSeed + 11) * interval + event * interval) +
          24 +
          seedUnit(seed + 23) * 58,
      family:
          DataVaultArcFamily.values[(seedUnit(seed + 29) *
                  DataVaultArcFamily.values.length)
              .floor()],
    );
  }

  static int arcEpisodeIndexAt(double seconds, int lane) {
    final railSeed = _impulseSeed(lane * 479 + 31);
    final interval = 1.05 + seedUnit(railSeed + 7) * 1.18;
    return ((seconds - seedUnit(railSeed + 11) * interval) / interval).floor();
  }

  static DataVaultScanPattern scanPatternFor(int seed) {
    final selector = seedUnit(seed + 107);
    return selector < .50
        ? DataVaultScanPattern.surfaceSweep
        : selector < .70
        ? DataVaultScanPattern.gate
        : DataVaultScanPattern.stripRaster;
  }

  static DataVaultNodeEvent nodeEventFor(int track, int event) {
    final trackSeed = _impulseSeed(track * 887 + 211);
    final seed = _impulseSeed(trackSeed + event * 557);
    final interval = 1.45 + seedUnit(trackSeed + 5) * 1.35;
    final launch = seedUnit(trackSeed + 13) * interval + event * interval;
    final selector = seedUnit(seed + 3);
    final topology = selector < .35
        ? DataVaultNodeTopology.singleHop
        : selector < .65
        ? DataVaultNodeTopology.relay
        : selector < .85
        ? DataVaultNodeTopology.fork
        : DataVaultNodeTopology.converge;
    final anchors = _nodeAnchorSet(seed, topology);
    final links = switch (topology) {
      DataVaultNodeTopology.singleHop => const [DataVaultNodeLink(0, 1, .02)],
      DataVaultNodeTopology.relay => const [
        DataVaultNodeLink(0, 1, .02, depthOffset: -.45),
        DataVaultNodeLink(1, 2, .16, depthOffset: -.82),
      ],
      DataVaultNodeTopology.fork => const [
        DataVaultNodeLink(0, 1, .02),
        DataVaultNodeLink(0, 2, .10, depthOffset: -.28),
      ],
      DataVaultNodeTopology.converge => const [
        DataVaultNodeLink(0, 2, .02),
        DataVaultNodeLink(1, 2, .10, depthOffset: -.24),
      ],
    };
    return DataVaultNodeEvent(
      id: event,
      seed: seed,
      launchSeconds: launch,
      duration: .40,
      anchorS: distanceAt(launch) + 22 + seedUnit(seed + 19) * 60,
      topology: topology,
      anchors: anchors,
      links: links,
    );
  }

  static List<DataVaultNodeAnchor> _nodeAnchorSet(
    int seed,
    DataVaultNodeTopology topology,
  ) {
    const catalog = DataVaultNodeAnchor.values;
    final first = (seedUnit(seed + 31) * catalog.length).floor();
    final second =
        (first + 3 + (seedUnit(seed + 37) * 5).floor()) % catalog.length;
    final third =
        (second + 4 + (seedUnit(seed + 41) * 5).floor()) % catalog.length;
    // Guarantee mixed physical surfaces, even when a hash happens to choose
    // neighbouring wall categories: each topology includes a floor/ceiling or
    // pillar contact in its compact three-node catalog.
    final forced = switch (topology) {
      DataVaultNodeTopology.singleHop => DataVaultNodeAnchor.floorCenter,
      DataVaultNodeTopology.relay => DataVaultNodeAnchor.pillarMid,
      DataVaultNodeTopology.fork => DataVaultNodeAnchor.ceilingCenter,
      DataVaultNodeTopology.converge => DataVaultNodeAnchor.floorRight,
    };
    return [catalog[first], forced, catalog[third]];
  }

  static int nodeEventIndexAt(double seconds, int track) {
    final trackSeed = _impulseSeed(track * 887 + 211);
    final interval = 1.45 + seedUnit(trackSeed + 5) * 1.35;
    return ((seconds - seedUnit(trackSeed + 13) * interval) / interval).floor();
  }

  /// A hybrid reaction is deliberately derived from a SPARK packet identity.
  /// The packet stays the dominant inbound image; the short arc happens only
  /// at its deterministic infrastructure interaction point.
  static DataVaultArcEpisode? hybridResponseFor(
    DataVaultImpulseSurface surface,
    int lane,
    int packet,
  ) {
    final profile = impulseProfileFor(surface, lane);
    final seed = packetSeed(surface, lane, packet);
    if (seedUnit(seed + 131) >= .30) return null;
    final launch = profile.launchOffset + packet * profile.repeatInterval;
    final onset = launch + .42 + seedUnit(seed + 137) * .42;
    final anchor = impulseHeadDistance(
      seconds: onset,
      launchSeconds: launch,
      speedMultiplier: profile.speedMultiplier,
    );
    return DataVaultArcEpisode(
      id: packet,
      seed: seed,
      launchSeconds: onset,
      lifetime: .16 + seedUnit(seed + 149) * .14,
      anchorS: anchor,
      family:
          DataVaultArcFamily.values[(seedUnit(seed + 151) *
                  DataVaultArcFamily.values.length)
              .floor()],
    );
  }

  static DataVaultInboundEvent arcEventFor(
    DataVaultImpulseSurface surface,
    int lane,
    int event,
  ) {
    final railSeed = packetSeed(surface, lane, 0);
    final seed = packetSeed(surface, lane, event);
    final interval = 1.25 + seedUnit(railSeed + 7) * 1.25;
    return DataVaultInboundEvent(
      id: event,
      seed: seed,
      launchSeconds: seedUnit(railSeed + 13) * interval + event * interval,
      travelMultiplier: 1.10 + seedUnit(seed + 23) * .50,
      length: .70 + seedUnit(seed + 31) * 1.70,
      lifetime: 3.4,
      lead: 90,
    );
  }

  static int arcEventIndexAt(
    double seconds,
    DataVaultImpulseSurface surface,
    int lane,
  ) {
    final seed = packetSeed(surface, lane, 0);
    final interval = 1.25 + seedUnit(seed + 7) * 1.25;
    return ((seconds - seedUnit(seed + 13) * interval) / interval).floor();
  }

  static DataVaultInboundEvent scanEventFor(
    DataVaultImpulseSurface surface,
    int lane,
    int event,
  ) {
    final railSeed = packetSeed(surface, lane + 71, 0);
    final seed = packetSeed(surface, lane + 71, event);
    final interval = 1.25 + seedUnit(railSeed + 5) * .65;
    return DataVaultInboundEvent(
      id: event,
      seed: seed,
      launchSeconds: seedUnit(railSeed + 17) * interval + event * interval,
      travelMultiplier: 1.05 + seedUnit(seed + 29) * .28,
      length: 1.2 + seedUnit(seed + 37) * .9,
      lifetime: 4.8,
      lead: 82,
    );
  }

  static int scanEventIndexAt(
    double seconds,
    DataVaultImpulseSurface surface,
    int lane,
  ) {
    final seed = packetSeed(surface, lane + 71, 0);
    final interval = 1.25 + seedUnit(seed + 5) * .65;
    return ((seconds - seedUnit(seed + 17) * interval) / interval).floor();
  }

  /// V2.4 raises the global scan rate by exactly 25% (3.35 / 1.25).
  static int compositeScanIndexAt(double seconds) =>
      ((seconds - .55) / 2.68).floor();

  static DataVaultInboundEvent compositeScanEventFor(int event) {
    final seed = _impulseSeed(0x47ad + event * 613);
    final launch = .55 + event * 2.68;
    return DataVaultInboundEvent(
      id: event,
      seed: seed,
      launchSeconds: launch,
      travelMultiplier: 1.08 + seedUnit(seed + 7) * .20,
      length: 1.5 + seedUnit(seed + 11) * 1.0,
      // The scan now remains active long enough to cross the usable depth
      // range even through a sprint, while its front stays world-projected.
      lifetime: 4.35,
      lead: 82,
    );
  }

  static DataVaultScanPattern compositeScanPatternFor(int seed) {
    final selector = seedUnit(seed + 101);
    return selector < .60
        ? DataVaultScanPattern.surfaceSweep
        : selector < .70
        ? DataVaultScanPattern.gate
        : DataVaultScanPattern.stripRaster;
  }

  /// V2.4 raises the global node cadence by exactly 25% (5.65 / 1.25).
  static int compositeNodeIndexAt(double seconds) =>
      ((seconds - 1.25) / 4.52).floor();

  static DataVaultNodeEvent compositeNodeEventFor(int event) {
    final base = nodeEventFor(event % 5, event);
    final launch = 1.25 + event * 4.52;
    return DataVaultNodeEvent(
      id: event,
      seed: base.seed,
      launchSeconds: launch,
      duration: .65,
      // A mid-near deterministic launch band avoids spending a short flash
      // beyond the aperture while retaining stable anchors for its lifetime.
      anchorS: distanceAt(launch) + 18 + seedUnit(base.seed + 19) * 48,
      topology: base.topology,
      anchors: base.anchors,
      links: base.links,
    );
  }

  static DataVaultNodeCascade nodeCascadeFor(
    int side,
    int event, {
    int track = 0,
  }) {
    final railSeed = _impulseSeed(side * 113 + 97);
    final seed = _impulseSeed(side * 113 + event * 421 + track * 79 + 97);
    final interval = 2.15 + seedUnit(railSeed + 3) * 1.05;
    return DataVaultNodeCascade(
      id: event,
      seed: seed,
      launchSeconds:
          seedUnit(railSeed + 11) * interval +
          track * interval * .23 +
          event * interval,
      travelMultiplier: 1.18 + seedUnit(seed + 19) * .25,
    );
  }

  static int nodeCascadeIndexAt(double seconds, int side, {int track = 0}) {
    final seed = _impulseSeed(side * 113 + 97);
    final interval = 2.15 + seedUnit(seed + 3) * 1.05;
    return ((seconds -
                seedUnit(seed + 11) * interval -
                track * interval * .23) /
            interval)
        .floor();
  }

  static DataVaultImpulseVariant impulseVariantFor(
    DataVaultImpulseSurface surface,
    int lane,
    int packet,
  ) {
    final seed = packetSeed(surface, lane, packet);
    final selector = seedUnit(seed + 3);
    final family = selector < .50
        ? DataVaultImpulseFamily.shortPacket
        : selector < .85
        ? DataVaultImpulseFamily.mediumPacket
        : DataVaultImpulseFamily.longBurst;
    final length = switch (family) {
      DataVaultImpulseFamily.shortPacket => .56 + seedUnit(seed + 17) * .22,
      DataVaultImpulseFamily.mediumPacket => .92 + seedUnit(seed + 17) * .30,
      DataVaultImpulseFamily.longBurst => 1.42 + seedUnit(seed + 17) * .42,
    };
    return DataVaultImpulseVariant(
      family: family,
      colorIndex: (seedUnit(seed + 29) * 4).floor().clamp(0, 3),
      tailMultiplier: length,
      brightnessMultiplier: .84 + seedUnit(seed + 43) * .30,
    );
  }

  /// Stable 70% D-SPARK event gate.  The seed includes every physical rail
  /// and packet identity, so all surfaces retain comparable representation.
  static bool retainSparkPacket(
    DataVaultImpulseSurface surface,
    int lane,
    int packet,
  ) => seedUnit(packetSeed(surface, lane, packet) + 0x70) < .70;

  /// A floor packet owns a physical, gently drifting world path. It is not
  /// coupled to the decorative -3.2/-1.6/0/1.6/3.2 floor-grid offsets.
  static double floorImpulseLateralAt(int lane, int packet, double s) {
    final seed = packetSeed(DataVaultImpulseSurface.floor, lane, packet);
    final base = -3.35 + seedUnit(seed) * 6.7;
    final drift = (seedUnit(seed + 29) - .5) * .72;
    final wave = .10 + seedUnit(seed + 47) * .12;
    final phase = seedUnit(seed + 71) * math.pi * 2;
    return (base + drift * math.sin(s * wave + phase)).clamp(-3.68, 3.68);
  }

  /// An incoming impulse starts beyond the usable far range at its own launch
  /// time and advances toward the viewer along the curved world coordinate.
  /// It has no modulo reset while inside the projected corridor.
  static double impulseHeadDistance({
    required double seconds,
    required double launchSeconds,
    required double speedMultiplier,
  }) {
    final launchDistance = distanceAt(launchSeconds);
    return launchDistance +
        96 -
        speedMultiplier * (distanceAt(seconds) - launchDistance);
  }

  static double smooth(double u) {
    final c = u.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  static double baseSpeedAt(double seconds) {
    final t = ((seconds % cycleSeconds) + cycleSeconds) % cycleSeconds;
    if (t < 12) return 7 * _speedMultiplier;
    if (t < 17) return (7 + 9 * smooth((t - 12) / 5)) * _speedMultiplier;
    if (t < 22) return 16 * _speedMultiplier;
    if (t < 27) return (16 - 5 * smooth((t - 22) / 5)) * _speedMultiplier;
    if (t < 36) return 11 * _speedMultiplier;
    if (t < 42) return (11 - 4 * smooth((t - 36) / 6)) * _speedMultiplier;
    return 7 * _speedMultiplier;
  }

  /// One low-frequency wave makes ordinary transit breathe without changing
  /// the 48-second world schedule. It is value and derivative continuous at
  /// the cycle boundary.
  static double speedWaveAt(double seconds) {
    final phase = ((seconds % cycleSeconds) + cycleSeconds) % cycleSeconds;
    return 1.05 - .05 * math.cos(math.pi * 2 * phase / cycleSeconds);
  }

  /// Smooth, deterministic boost envelopes with zero value and derivative at
  /// their endpoints. The peak is 1.55–1.90x the active base state.
  static double boostStrengthAt(double seconds) {
    final t = ((seconds % cycleSeconds) + cycleSeconds) % cycleSeconds;
    var value = 0.0;
    for (final window in _boostWindows) {
      if (t < window.$1 || t > window.$1 + window.$2) continue;
      final u = (t - window.$1) / window.$2;
      value = math.max(value, math.sin(math.pi * u));
    }
    return value;
  }

  static double boostMultiplierAt(double seconds) {
    final t = ((seconds % cycleSeconds) + cycleSeconds) % cycleSeconds;
    var multiplier = 1.0;
    for (final window in _boostWindows) {
      if (t < window.$1 || t > window.$1 + window.$2) continue;
      final u = (t - window.$1) / window.$2;
      final envelope = .5 - .5 * math.cos(math.pi * 2 * u);
      multiplier = math.max(multiplier, 1 + (window.$3 - 1) * envelope);
    }
    return multiplier;
  }

  static double speedAt(double seconds) =>
      baseSpeedAt(seconds) * speedWaveAt(seconds) * boostMultiplierAt(seconds);

  /// Smoothly advances the beacon up the projected route while sprinting.
  /// The world offset, rather than a screen overlay, keeps it on the road.
  static double beaconSprintAdvance(double speed, [double? seconds]) {
    final u = ((speed - 14.175) / (32.4 - 14.175)).clamp(0.0, 1.0);
    final boost = seconds == null ? 0.0 : boostStrengthAt(seconds);
    return 2.2 * smooth(u) + 1.35 * boost;
  }

  static double distanceAt(double seconds) {
    final cycles = (seconds / cycleSeconds).floor();
    final t = seconds - cycles * cycleSeconds;
    final index = (t / _distanceStep).floor().clamp(
      0,
      _distanceTable.length - 1,
    );
    final remaining = t - index * _distanceStep;
    final integral =
        _distanceTable[index] +
        _integrateInterval(index * _distanceStep, remaining);
    return cycles * distancePerCycle + integral;
  }

  static List<double> _buildDistanceTable() {
    final values = <double>[0];
    var total = 0.0;
    for (
      var index = 0;
      index < (cycleSeconds / _distanceStep).round();
      index++
    ) {
      total += _integrateInterval(index * _distanceStep, _distanceStep);
      values.add(total);
    }
    return values;
  }

  static double _integrateInterval(double start, double duration) {
    if (duration <= 0) return 0;
    // Simpson integration keeps the cumulative world coordinate continuous
    // while all expensive work stays bounded in a small static lookup table.
    final middle = start + duration / 2;
    return duration /
        6 *
        (speedAt(start) + 4 * speedAt(middle) + speedAt(start + duration));
  }

  static DataVaultBeaconPulse beaconPulseAt(double seconds) {
    final slow = math.sin(math.pi * 2 * seconds / 3.2 + .43);
    final flutter = math.sin(math.pi * 2 * seconds / .68 + 1.17);
    final breath = ((slow + 1) / 2 + flutter * .10).clamp(0.0, 1.0);
    return DataVaultBeaconPulse(
      breath: breath,
      outerRadius: .92 + .20 * breath,
      outerAlpha: .75 + .60 * breath,
      midAlpha: .78 + .40 * breath,
      coreAlpha: .88 + .20 * breath,
    );
  }

  static double impulseVisibility(double depth) =>
      ((depth - 3) / 5).clamp(0.0, 1.0) * ((90 - depth) / 18).clamp(0.0, 1.0);

  static double pillarAccessResponse(
    double seconds,
    double cameraDistance,
    double pillarDistance,
  ) {
    var response = 0.0;
    for (var lane = 0; lane < 5; lane++) {
      final profile = impulseProfileFor(DataVaultImpulseSurface.floor, lane);
      final current =
          ((seconds - profile.launchOffset) / profile.repeatInterval).floor();
      for (var packet = current; packet >= current - 2; packet--) {
        final launch = profile.launchOffset + packet * profile.repeatInterval;
        final elapsed = seconds - launch;
        if (elapsed < 0 || elapsed > profile.visibleDuration) continue;
        final head = impulseHeadDistance(
          seconds: seconds,
          launchSeconds: launch,
          speedMultiplier: profile.speedMultiplier,
        );
        final difference = (pillarDistance - head).abs();
        if (difference >= 4.4) continue;
        final normalized = 1 - difference / 4.4;
        response = math.max(response, normalized * normalized);
      }
    }
    return response;
  }

  static double curvatureAt(double s) {
    final base =
        .006 * math.sin(math.pi * 2 * s / 180) +
        .013 * math.sin(math.pi * 2 * s / 420);
    final r = ((s % 240) + 240) % 240;
    return base +
        _turnEnvelope(r, 40, 105, .018) +
        _turnEnvelope(r, 130, 195, -.018);
  }

  static double _turnEnvelope(double r, double start, double end, double peak) {
    if (r < start || r > end) return 0;
    if (r < start + 20) {
      return peak * smooth((r - start) / 20);
    }
    if (r > end - 20) {
      return peak * smooth((end - r) / 20);
    }
    return peak;
  }
}

class _VaultWorld {
  final List<_VaultSample> _cache = [_VaultSample.zero()];
  double curvatureAt(double s) => HistoryDataVaultMotion.curvatureAt(s);

  void prepare(double target, {required double retainFrom}) {
    // Runtime time only advances, but deterministic tests can request an
    // earlier explicit simulation timestamp. Rebuild instead of projecting
    // a stale far-future sample and producing an invalid camera basis.
    if (_cache.first.s > target) {
      _cache
        ..clear()
        ..add(_VaultSample.zero());
    }
    while (_cache.last.s < target) {
      final previous = _cache.last;
      final step = .5;
      final heading =
          previous.heading + curvatureAt(previous.s + step / 2) * step;
      _cache.add(
        _VaultSample(
          previous.s + step,
          previous.x + math.sin(heading) * step,
          previous.z + math.cos(heading) * step,
          heading,
        ),
      );
    }
    while (_cache.length > 720 && _cache[1].s < retainFrom) {
      _cache.removeAt(0);
    }
  }

  _VaultSample sample(double s) {
    if (s <= 0) return _VaultSample.zero();
    // Sampling a camera look-ahead must not discard the near segment that
    // surfaces, route trails, and packet tails still need in this paint pass.
    prepare(s, retainFrom: _cache.first.s);
    for (var index = _cache.length - 2; index >= 0; index--) {
      final a = _cache[index];
      final b = _cache[index + 1];
      if (a.s <= s && s <= b.s) {
        return _VaultSample.lerp(a, b, (s - a.s) / (b.s - a.s));
      }
    }
    return _cache.last;
  }
}

class _VaultSample {
  const _VaultSample(this.s, this.x, this.z, this.heading);
  factory _VaultSample.zero() => const _VaultSample(0, 0, 0, 0);
  factory _VaultSample.lerp(_VaultSample a, _VaultSample b, double t) =>
      _VaultSample(
        a.s + (b.s - a.s) * t,
        a.x + (b.x - a.x) * t,
        a.z + (b.z - a.z) * t,
        a.heading + (b.heading - a.heading) * t,
      );
  final double s, x, z, heading;
  double get tangentX => math.sin(heading);
  double get tangentZ => math.cos(heading);
  _WorldPoint point(double lateral, double y) => _WorldPoint(
    x + math.cos(heading) * lateral,
    y,
    z - math.sin(heading) * lateral,
  );
}

class _WorldPoint {
  const _WorldPoint(this.x, this.y, this.z);
  final double x, y, z;
  _WorldPoint translate(double dx, double dz) => _WorldPoint(x + dx, y, z + dz);
}

class _CameraPoint {
  const _CameraPoint(this.x, this.y, this.z);
  final double x, y, z;
}

class _Projected {
  const _Projected(this.offset, this.z);
  final Offset offset;
  final double z;
}

class _VaultCamera {
  _VaultCamera({
    required _VaultSample position,
    required _VaultSample target,
    required this.distance,
    required double curvature,
    required this.size,
  }) : _position = position,
       _forwardX = _normX(target.x - position.x, target.z - position.z),
       _forwardZ = _normZ(target.x - position.x, target.z - position.z),
       roll = (-35 * curvature).clamp(-math.pi / 60, math.pi / 60) {
    _rightX = _forwardZ;
    _rightZ = -_forwardX;
  }
  final _VaultSample _position;
  final Size size;
  final double distance, roll;
  late final double _forwardX, _forwardZ, _rightX, _rightZ;
  static double _normX(double x, double z) {
    final l = math.sqrt(x * x + z * z);
    return x / l;
  }

  static double _normZ(double x, double z) {
    final l = math.sqrt(x * x + z * z);
    return z / l;
  }

  _CameraPoint camera(_WorldPoint p) => _CameraPoint(
    (p.x - _position.x) * _rightX + (p.z - _position.z) * _rightZ,
    p.y - 2.2,
    (p.x - _position.x) * _forwardX + (p.z - _position.z) * _forwardZ,
  );
  List<_CameraPoint> clip(List<_WorldPoint> world) {
    final input = world.map(camera).toList();
    final output = <_CameraPoint>[];
    for (var i = 0; i < input.length; i++) {
      final a = input[i], b = input[(i + 1) % input.length];
      final ai = a.z > .5, bi = b.z > .5;
      if (ai) output.add(a);
      if (ai != bi) {
        final t = (.5 - a.z) / (b.z - a.z);
        output.add(
          _CameraPoint(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, .5),
        );
      }
    }
    return output;
  }

  _Projected? project(_WorldPoint p) => projectCamera(camera(p));
  _Projected? projectCamera(_CameraPoint p) {
    if (p.z <= .5 || p.z > 100) return null;
    final f = size.height / (2 * math.tan(65 * math.pi / 360));
    final c = math.cos(roll), s = math.sin(roll);
    final x = p.x * c - p.y * s, y = p.x * s + p.y * c;
    return _Projected(
      Offset(size.width / 2 + f * x / p.z, size.height / 2 - f * y / p.z),
      p.z,
    );
  }
}
