import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/history_visual_preference.dart';

/// Deterministic, world-fixed DATA VAULT flight renderer.  It deliberately
/// owns only Ambient B geometry; HISTORY foreground UI remains outside it.
class HistoryDataVaultHyperspace {
  const HistoryDataVaultHyperspace({
    required this.seconds,
    this.impulseMode = DataVaultImpulseMode.arc,
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
    switch (impulseMode) {
      case DataVaultImpulseMode.arc:
        _paintArcTraffic(canvas, camera, cameraDistance, 10);
      case DataVaultImpulseMode.scan:
        _paintSurfaceScans(canvas, camera, cameraDistance);
      case DataVaultImpulseMode.node:
        _paintNodeDischarges(canvas, camera, cameraDistance);
      case DataVaultImpulseMode.spark:
        _paintDataTraffic(canvas, camera, cameraDistance);
      case DataVaultImpulseMode.hybrid:
        _paintArcTraffic(canvas, camera, cameraDistance, 6);
        _paintDataTraffic(canvas, camera, cameraDistance, maxRails: 4);
    }
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

  void _paintArcTraffic(
    Canvas canvas,
    _VaultCamera camera,
    double distance,
    int cap,
  ) {
    var painted = 0;
    for (final rail in _comparisonRails) {
      final current = HistoryDataVaultMotion.arcEventIndexAt(
        seconds,
        rail.surface,
        rail.lane,
      );
      for (
        var index = current;
        index >= current - 3 && painted < cap;
        index--
      ) {
        final event = HistoryDataVaultMotion.arcEventFor(
          rail.surface,
          rail.lane,
          index,
        );
        if (!event.isActiveAt(seconds)) continue;
        if (_paintMovingArc(canvas, camera, distance, rail, event)) painted++;
      }
      if (painted >= cap) break;
    }
  }

  bool _paintMovingArc(
    Canvas canvas,
    _VaultCamera camera,
    double distance,
    _DataVaultRail rail,
    DataVaultInboundEvent event,
  ) {
    final head = event.frontAt(seconds);
    if (head < distance - 5 || head > distance + 94) return false;
    final points = <_WorldPoint>[];
    const segmentCount = 4;
    for (var index = 0; index <= segmentCount; index++) {
      final u = index / segmentCount;
      final s = head + event.length * (1 - u);
      final seed = HistoryDataVaultMotion.seedUnit(event.seed + index * 37);
      final jitterLimit = rail.surface == DataVaultImpulseSurface.floor
          ? .09
          : .07;
      final jitter = (seed - .5) * 2 * jitterLimit;
      final lateral = rail.surface == DataVaultImpulseSurface.floor
          ? HistoryDataVaultMotion.floorImpulseLateralAt(
                  rail.lane,
                  event.id,
                  s,
                ) +
                jitter
          : rail.lateral + jitter;
      points.add(_world.sample(s).point(lateral, rail.height));
    }
    final headProjected = camera.project(points.last);
    if (headProjected == null) return false;
    final visibility = HistoryDataVaultMotion.impulseVisibility(
      headProjected.z,
    );
    if (visibility <= 0) return false;
    final tint = _arcColor(event.seed);
    for (var index = 0; index < points.length - 1; index++) {
      final tip = (index + 1) / (points.length - 1);
      final alpha = visibility * tip * tip;
      _strokeWorldLine(
        canvas,
        camera,
        points[index],
        points[index + 1],
        tint.withValues(alpha: .08 * alpha),
        4.5,
      );
      _strokeWorldLine(
        canvas,
        camera,
        points[index],
        points[index + 1],
        tint.withValues(alpha: .20 * alpha),
        2.5,
      );
      _strokeWorldLine(
        canvas,
        camera,
        points[index],
        points[index + 1],
        const Color(0xffddfbff).withValues(alpha: (.80 * alpha).clamp(0, 1)),
        .9,
      );
    }
    if (HistoryDataVaultMotion.seedUnit(event.seed + 91) < .15) {
      final branchStart = points[points.length - 2];
      final branchEnd = _world
          .sample(head + .32)
          .point(
            rail.surface == DataVaultImpulseSurface.floor
                ? rail.lateral + .16
                : rail.lateral,
            (rail.height + .18).clamp(.05, 4.88),
          );
      _strokeWorldLine(
        canvas,
        camera,
        branchStart,
        branchEnd,
        tint.withValues(alpha: .24 * visibility),
        .65,
      );
    }
    return true;
  }

  Color _arcColor(int seed) => const [
    Color(0xff64e6f8),
    Color(0xff36bdeb),
    Color(0xffb8f4ff),
    Color(0xff6285ff),
  ][(HistoryDataVaultMotion.seedUnit(seed + 17) * 4).floor().clamp(0, 3)];

  void _paintSurfaceScans(Canvas canvas, _VaultCamera camera, double distance) {
    const scans = <_DataVaultRail>[
      _DataVaultRail(DataVaultImpulseSurface.floor, 0, -1.6, .04),
      _DataVaultRail(DataVaultImpulseSurface.floor, 1, 1.45, .04),
      _DataVaultRail(DataVaultImpulseSurface.leftWall, 0, -3.95, 2.15),
      _DataVaultRail(DataVaultImpulseSurface.rightWall, 0, 3.95, 2.9),
      _DataVaultRail(DataVaultImpulseSurface.ceiling, 0, 0, 4.88),
    ];
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
        final width = rail.surface == DataVaultImpulseSurface.floor
            ? 2.0
            : 1.25;
        final tail = head + event.length;
        _fillWorldQuad(canvas, camera, [
          _scanPoint(rail, head, -width),
          _scanPoint(rail, head, width),
          _scanPoint(rail, tail, width),
          _scanPoint(rail, tail, -width),
        ], const Color(0xff36bdeb).withValues(alpha: .09));
        for (var notch = 0; notch < 6; notch++) {
          final u = notch / 5;
          final from = -width + width * 2 * u;
          _strokeWorldLine(
            canvas,
            camera,
            _scanPoint(rail, head, from),
            _scanPoint(rail, head + .22, from + .14),
            const Color(0xffddfbff).withValues(alpha: .72),
            .85,
          );
        }
      }
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

  void _paintNodeDischarges(
    Canvas canvas,
    _VaultCamera camera,
    double distance,
  ) {
    var painted = 0;
    for (var side = -1; side <= 1 && painted < 4; side += 2) {
      // Four staggered deterministic channels leave at least one localized
      // cascade visible without synchronising the two walls or rendering an
      // entire chart-like chain at once.
      for (var track = 0; track < 4 && painted < 4; track++) {
        final current = HistoryDataVaultMotion.nodeCascadeIndexAt(
          seconds,
          side,
          track: track,
        );
        for (
          var index = current;
          index >= current - 2 && painted < 4;
          index--
        ) {
          final cascade = HistoryDataVaultMotion.nodeCascadeFor(
            side,
            index,
            track: track,
          );
          final hop = cascade.activeHopAt(seconds);
          if (hop == null) continue;
          final front = cascade.frontAt(seconds);
          final farS = front + (3 - hop) * 3.6;
          final nearS = farS - 3.6;
          if (nearS < distance - 5 || farS > distance + 94) continue;
          _paintNodeHop(canvas, camera, side, hop, farS, nearS, cascade.seed);
          painted++;
        }
      }
    }
  }

  void _paintNodeHop(
    Canvas canvas,
    _VaultCamera camera,
    int side,
    int hop,
    double farS,
    double nearS,
    int seed,
  ) {
    final points = <_WorldPoint>[];
    for (var index = 0; index < 4; index++) {
      final u = index / 3;
      final s = farS + (nearS - farS) * u;
      final lateral = side * (3.8 - (hop.isEven ? .10 * u : .24 * (1 - u)));
      final height = switch ((hop + index) % 3) {
        0 => 3.72 - 2.6 * u,
        1 => .08 + 1.1 * u,
        _ => 1.12 + 3.76 * u,
      };
      final jitter =
          (HistoryDataVaultMotion.seedUnit(seed + index * 19) - .5) * .12;
      points.add(
        _world.sample(s).point(lateral + jitter, height.clamp(.05, 4.88)),
      );
    }
    for (final layer in [(4.0, .12), (2.0, .28), (1.0, .88)]) {
      _strokeWorldPolyline(
        canvas,
        camera,
        points,
        const Color(0xff64e6f8).withValues(alpha: layer.$2),
        layer.$1,
      );
    }
    for (final node in [points.first, points.last]) {
      final projected = camera.project(node);
      if (projected == null) continue;
      canvas.drawCircle(
        projected.offset,
        3.4,
        Paint()..color = const Color(0xff36bdeb).withValues(alpha: .18),
      );
      canvas.drawCircle(
        projected.offset,
        1.0,
        Paint()..color = const Color(0xffddfbff).withValues(alpha: .88),
      );
    }
  }

  static const _comparisonRails = <_DataVaultRail>[
    _DataVaultRail(DataVaultImpulseSurface.floor, 0, -3.1, .05),
    _DataVaultRail(DataVaultImpulseSurface.floor, 1, -.8, .05),
    _DataVaultRail(DataVaultImpulseSurface.floor, 2, 1.2, .05),
    _DataVaultRail(DataVaultImpulseSurface.floor, 3, 3.0, .05),
    _DataVaultRail(DataVaultImpulseSurface.leftWall, 0, -3.94, 1.25),
    _DataVaultRail(DataVaultImpulseSurface.leftWall, 1, -3.94, 3.6),
    _DataVaultRail(DataVaultImpulseSurface.rightWall, 0, 3.94, 1.4),
    _DataVaultRail(DataVaultImpulseSurface.rightWall, 1, 3.94, 3.8),
    _DataVaultRail(DataVaultImpulseSurface.ceiling, 0, -1.8, 4.88),
    _DataVaultRail(DataVaultImpulseSurface.ceiling, 1, 1.5, 4.88),
  ];

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
