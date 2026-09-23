import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cat_run_v24_presentation.dart';
import 'cat_run_v2_registration.dart';
import 'cat_run_v2_trace_data.dart';

/// The five complete CAT identities available to the sandbox and a future
/// appearance scheduler. RANDOM is intentionally not a visual identity.
enum CatRunCoatVariant { normal, hachiware, calico, kijitora, sabi }

extension CatRunCoatVariantLabel on CatRunCoatVariant {
  String get label => switch (this) {
    CatRunCoatVariant.normal => 'NORMAL',
    CatRunCoatVariant.hachiware => 'HACHIWARE',
    CatRunCoatVariant.calico => 'CALICO',
    CatRunCoatVariant.kijitora => 'KIJITORA',
    CatRunCoatVariant.sabi => 'SABI',
  };
}

/// Vector-only, silhouette-clipped coat overlays for the frozen HIGH frames.
/// Coordinates derive from the registered shoulder-to-pelvis axis for each
/// frame, so a selected identity follows the body instead of screen space.
class CatRunCoatPatterns {
  CatRunCoatPatterns._();

  static const visualVariants = <CatRunCoatVariant>[
    CatRunCoatVariant.normal,
    CatRunCoatVariant.hachiware,
    CatRunCoatVariant.calico,
    CatRunCoatVariant.kijitora,
    CatRunCoatVariant.sabi,
  ];

  static const probabilities = <CatRunCoatVariant, double>{
    CatRunCoatVariant.normal: .2,
    CatRunCoatVariant.hachiware: .2,
    CatRunCoatVariant.calico: .2,
    CatRunCoatVariant.kijitora: .2,
    CatRunCoatVariant.sabi: .2,
  };

  /// Keep NORMAL exactly equivalent to the existing V2.10 base rendering.
  static const patternColor = Color(0xFF383838);

  static CatRunCoatVariant chooseRandom(math.Random random) =>
      visualVariants[random.nextInt(visualVariants.length)];

  static void paint({
    required Canvas canvas,
    required Path silhouette,
    required CatRunV2Trace trace,
    required CatRunCoatVariant variant,
  }) {
    if (variant == CatRunCoatVariant.normal) return;
    final anatomy = _CoatAnatomy.fromTrace(trace);
    final paint = Paint()
      ..color = patternColor
      ..isAntiAlias = true;
    canvas.save();
    // This clip is authoritative: no pattern path can escape the CAT path.
    canvas.clipPath(silhouette);
    switch (variant) {
      case CatRunCoatVariant.normal:
        break;
      case CatRunCoatVariant.hachiware:
        _paintHachiware(canvas, paint, anatomy);
      case CatRunCoatVariant.calico:
        _paintCalico(canvas, paint, anatomy);
      case CatRunCoatVariant.kijitora:
        _paintKijitora(canvas, paint, anatomy);
      case CatRunCoatVariant.sabi:
        _paintSabi(canvas, paint, anatomy);
    }
    canvas.restore();
  }

  static void _paintHachiware(Canvas canvas, Paint paint, _CoatAnatomy a) {
    // Broad lower-face blaze and bib: deliberately legible at 48px.
    canvas.drawPath(
      _polygon(a, const [
        Offset(-.48, -.12), Offset(-.21, -.18), Offset(-.08, .04),
        Offset(-.18, .28), Offset(-.42, .25),
      ]),
      paint,
    );
    canvas.drawPath(
      _polygon(a, const [
        Offset(-.05, -.18), Offset(.22, -.25), Offset(.40, .02),
        Offset(.29, .25), Offset(.06, .30),
      ]),
      paint,
    );
    canvas.drawPath(
      _polygon(a, const [
        Offset(.22, -.15), Offset(.48, -.13), Offset(.53, .10),
        Offset(.32, .14),
      ]),
      paint,
    );
  }

  static void _paintCalico(Canvas canvas, Paint paint, _CoatAnatomy a) {
    // Few large, separated islands distinguish CALICO from SABI.
    canvas.drawPath(_blob(a, const [
      Offset(-.35, -.38), Offset(-.05, -.48), Offset(.10, -.24),
      Offset(-.04, .02), Offset(-.32, -.04),
    ]), paint);
    canvas.drawPath(_blob(a, const [
      Offset(.28, .10), Offset(.56, -.03), Offset(.74, .18),
      Offset(.63, .45), Offset(.34, .40),
    ]), paint);
    canvas.drawPath(_blob(a, const [
      Offset(.80, -.37), Offset(1.14, -.32), Offset(1.24, -.05),
      Offset(1.06, .18), Offset(.82, .07),
    ]), paint);
  }

  static void _paintKijitora(Canvas canvas, Paint paint, _CoatAnatomy a) {
    // Wide diagonal bands avoid high-frequency flicker at production scale.
    for (final start in [-.05, .20, .45, .70, .95]) {
      canvas.drawPath(_polygon(a, [
        Offset(start, -.47), Offset(start + .12, -.46),
        Offset(start + .27, .43), Offset(start + .12, .44),
      ]), paint);
    }
    // The two broad tail bands are clipped to the traced tail silhouette.
    for (final start in [1.08, 1.34]) {
      canvas.drawPath(_polygon(a, [
        Offset(start, -.26), Offset(start + .10, -.25),
        Offset(start + .18, .26), Offset(start + .07, .27),
      ]), paint);
    }
  }

  static void _paintSabi(Canvas canvas, Paint paint, _CoatAnatomy a) {
    // Smaller, more distributed islands than CALICO, but still intentionally
    // broad enough not to turn into animated noise at a 48px stage.
    for (final patch in const [
      [Offset(-.40, -.30), Offset(-.20, -.34), Offset(-.12, -.15), Offset(-.30, -.06)],
      [Offset(.02, .22), Offset(.22, .10), Offset(.34, .28), Offset(.17, .43)],
      [Offset(.36, -.39), Offset(.57, -.34), Offset(.63, -.16), Offset(.44, -.10)],
      [Offset(.66, .15), Offset(.86, .06), Offset(.96, .25), Offset(.79, .39)],
      [Offset(1.02, -.14), Offset(1.19, -.10), Offset(1.24, .07), Offset(1.08, .14)],
    ]) {
      canvas.drawPath(_blob(a, patch), paint);
    }
  }

  static Path _polygon(_CoatAnatomy anatomy, List<Offset> points) {
    final first = anatomy.at(points.first);
    final path = Path()..moveTo(first.dx, first.dy);
    for (final point in points.skip(1)) {
      final transformed = anatomy.at(point);
      path.lineTo(transformed.dx, transformed.dy);
    }
    return path..close();
  }

  static Path _blob(_CoatAnatomy anatomy, List<Offset> points) {
    final first = anatomy.at(points.first);
    final path = Path()..moveTo(first.dx, first.dy);
    for (var index = 0; index < points.length; index++) {
      final current = anatomy.at(points[index]);
      final next = anatomy.at(points[(index + 1) % points.length]);
      path.quadraticBezierTo(current.dx, current.dy, (current.dx + next.dx) / 2,
          (current.dy + next.dy) / 2);
    }
    return path..close();
  }
}

class _CoatAnatomy {
  const _CoatAnatomy(this.shoulder, this.axis);

  factory _CoatAnatomy.fromTrace(CatRunV2Trace trace) {
    final registration = CatRunV2Registration.registrationFor(trace.pose);
    final transform = CatRunV2Registration.transformFor(trace);
    final shoulder = CatRunV24ScaleAudit.correctedAnatomicalPoint(
      trace,
      transform.apply(registration.shoulder * (1 / 800)),
    );
    final pelvis = CatRunV24ScaleAudit.correctedAnatomicalPoint(
      trace,
      transform.apply(registration.pelvis * (1 / 800)),
    );
    return _CoatAnatomy(shoulder, pelvis - shoulder);
  }

  final Offset shoulder;
  final Offset axis;

  Offset at(Offset local) {
    final normal = Offset(-axis.dy, axis.dx);
    return shoulder + (axis * local.dx) + (normal * local.dy);
  }
}
