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

  /// A dark ambient silhouette with a restrained, secondary coat contrast.
  /// NORMAL draws only [baseColor].
  static const baseColor = Color(0xFF7A7A7A);
  static const patternColor = Color(0xFF565656);

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
    // An irregular forehead division, face-side marking, and soft bib are
    // broad enough for 48px without reading as two pasted-on face blocks.
    canvas.drawPath(
      _organicPatch(a, const [
        Offset(-.53, -.18), Offset(-.37, -.33), Offset(-.16, -.27),
        Offset(-.07, -.04), Offset(-.20, .14), Offset(-.43, .19),
        Offset(-.55, .04),
      ]),
      paint,
    );
    canvas.drawPath(
      _organicPatch(a, const [
        Offset(-.22, .03), Offset(-.02, -.04), Offset(.18, .05),
        Offset(.29, .26), Offset(.16, .43), Offset(-.07, .35),
        Offset(-.19, .20),
      ]),
      paint,
    );
    canvas.drawPath(
      _organicPatch(a, const [
        Offset(.27, -.19), Offset(.47, -.12), Offset(.55, .04),
        Offset(.44, .17), Offset(.28, .13), Offset(.20, -.01),
      ]),
      paint,
    );
  }

  static void _paintCalico(Canvas canvas, Paint paint, _CoatAnatomy a) {
    // Few large, asymmetric islands distinguish CALICO from SABI.
    canvas.drawPath(_organicPatch(a, const [
      Offset(-.43, -.42), Offset(-.20, -.52), Offset(.03, -.37),
      Offset(.10, -.15), Offset(-.09, .01), Offset(-.33, -.07),
      Offset(-.47, -.23),
    ]), paint);
    canvas.drawPath(_organicPatch(a, const [
      Offset(.23, .08), Offset(.43, -.09), Offset(.68, -.01),
      Offset(.79, .19), Offset(.64, .43), Offset(.37, .46),
      Offset(.21, .30),
    ]), paint);
    canvas.drawPath(_organicPatch(a, const [
      Offset(.79, -.40), Offset(1.06, -.46), Offset(1.25, -.29),
      Offset(1.28, -.05), Offset(1.08, .16), Offset(.87, .09),
      Offset(.75, -.13),
    ]), paint);
  }

  static void _paintKijitora(Canvas canvas, Paint paint, _CoatAnatomy a) {
    // A handful of curved, varied ribbons avoid barcode-like tabby bands.
    for (final stripe in const [
      (start: -.02, width: .13, bend: -.03, length: .72),
      (start: .25, width: .10, bend: .05, length: .84),
      (start: .49, width: .14, bend: -.04, length: .76),
      (start: .78, width: .09, bend: .03, length: .68),
    ]) {
      canvas.drawPath(
        _curvedStripe(
          a,
          start: stripe.start,
          width: stripe.width,
          bend: stripe.bend,
          length: stripe.length,
        ),
        paint,
      );
    }
    // Restrained, unequal tail bands remain clipped to the traced tail.
    for (final stripe in const [
      (start: 1.07, width: .09, bend: -.02, length: .43),
      (start: 1.34, width: .12, bend: .03, length: .36),
    ]) {
      canvas.drawPath(
        _curvedStripe(
          a,
          start: stripe.start,
          width: stripe.width,
          bend: stripe.bend,
          length: stripe.length,
        ),
        paint,
      );
    }
  }

  static void _paintSabi(Canvas canvas, Paint paint, _CoatAnatomy a) {
    // Smaller, more distributed irregular markings than CALICO, still broad
    // enough not to turn into animated noise at a 48px stage.
    for (final patch in const [
      [Offset(-.46, -.31), Offset(-.28, -.40), Offset(-.10, -.25), Offset(-.16, -.07), Offset(-.36, -.04)],
      [Offset(-.04, .20), Offset(.16, .08), Offset(.33, .19), Offset(.29, .39), Offset(.10, .45), Offset(-.08, .34)],
      [Offset(.29, -.43), Offset(.51, -.39), Offset(.64, -.22), Offset(.54, -.07), Offset(.35, -.12)],
      [Offset(.61, .13), Offset(.79, .02), Offset(.98, .15), Offset(.94, .34), Offset(.76, .42), Offset(.61, .30)],
      [Offset(.99, -.18), Offset(1.16, -.18), Offset(1.28, -.02), Offset(1.18, .13), Offset(1.02, .10)],
    ]) {
      canvas.drawPath(_organicPatch(a, patch), paint);
    }
  }

  static Path _organicPatch(_CoatAnatomy anatomy, List<Offset> points) {
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

  static Path _curvedStripe(
    _CoatAnatomy anatomy, {
    required double start,
    required double width,
    required double bend,
    required double length,
  }) {
    final top = anatomy.at(Offset(start, -.45));
    final upperCurve = anatomy.at(Offset(start + (length * .35), -.31 + bend));
    final lower = anatomy.at(Offset(start + length, .34));
    final lowerCurve = anatomy.at(
      Offset(start + (length * .58), .39 + bend),
    );
    final returnTop = anatomy.at(Offset(start + width, -.43));
    final path = Path()..moveTo(top.dx, top.dy);
    path.cubicTo(
      upperCurve.dx,
      upperCurve.dy,
      lowerCurve.dx,
      lowerCurve.dy,
      lower.dx,
      lower.dy,
    );
    path.cubicTo(
      lowerCurve.dx - (anatomy.axis.dx * width),
      lowerCurve.dy - (anatomy.axis.dy * width),
      upperCurve.dx - (anatomy.axis.dx * width),
      upperCurve.dy - (anatomy.axis.dy * width),
      returnTop.dx,
      returnTop.dy,
    );
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
