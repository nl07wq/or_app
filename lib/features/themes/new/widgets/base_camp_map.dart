import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:or_app/core/widgets/global_touch_ripple.dart';

/// The registered image remains the single visual source. Facility regions are
/// normalised against it so the image, feedback affordances, and hit testing
/// always receive the same [InteractiveViewer] transform.
const baseCampMapAsset = 'assets/images/themes/new/base_camp_map.png';

@immutable
class BaseCampFacility {
  const BaseCampFacility({
    required this.id,
    required this.label,
    required this.center,
    required this.size,
    this.frameCorners,
  });

  final String id;
  final String label;
  final Offset center;
  final Size size;

  /// Normalised, clockwise corners for the 2.5D selection frame.  Hit
  /// testing intentionally continues to use [center]/[size], keeping the
  /// existing generous facility targets unchanged.
  final List<Offset>? frameCorners;

  List<Offset> corners() {
    final customCorners = frameCorners;
    if (customCorners != null) return customCorners;
    final halfWidth = size.width / 2;
    final halfHeight = size.height / 2;
    return <Offset>[
      Offset(center.dx - halfWidth, center.dy - halfHeight),
      Offset(center.dx + halfWidth, center.dy - halfHeight),
      Offset(center.dx + halfWidth, center.dy + halfHeight),
      Offset(center.dx - halfWidth, center.dy + halfHeight),
    ];
  }
}

const baseCampFacilities = <BaseCampFacility>[
  BaseCampFacility(
    id: 'status',
    label: 'STATUS',
    center: Offset(.235, .355),
    size: Size(.24, .22),
    frameCorners: <Offset>[
      Offset(.125, .275),
      Offset(.345, .288),
      Offset(.335, .432),
      Offset(.12, .418),
    ],
  ),
  BaseCampFacility(
    id: 'food',
    label: 'FOOD',
    center: Offset(.500, .270),
    size: Size(.25, .20),
    frameCorners: <Offset>[
      Offset(.38, .195),
      Offset(.62, .204),
      Offset(.61, .335),
      Offset(.385, .325),
    ],
  ),
  BaseCampFacility(
    id: 'training',
    label: 'TRAINING',
    center: Offset(.785, .345),
    size: Size(.24, .24),
    frameCorners: <Offset>[
      Offset(.67, .255),
      Offset(.90, .275),
      Offset(.89, .43),
      Offset(.675, .413),
    ],
  ),
  BaseCampFacility(
    id: 'activity',
    label: 'ACTIVITY',
    center: Offset(.285, .630),
    size: Size(.25, .22),
    frameCorners: <Offset>[
      Offset(.17, .55),
      Offset(.41, .565),
      Offset(.40, .71),
      Offset(.175, .70),
    ],
  ),
  BaseCampFacility(
    id: 'command-center',
    label: 'COMMAND CENTER',
    center: Offset(.705, .640),
    size: Size(.28, .25),
    frameCorners: <Offset>[
      Offset(.57, .54),
      Offset(.84, .56),
      Offset(.83, .715),
      Offset(.575, .70),
    ],
  ),
];

class BaseCampMap extends StatefulWidget {
  const BaseCampMap({super.key, required this.onFacilityPressed});

  final ValueChanged<BaseCampFacility> onFacilityPressed;

  @override
  State<BaseCampMap> createState() => _BaseCampMapState();
}

class _BaseCampMapState extends State<BaseCampMap>
    with TickerProviderStateMixin {
  static const _interactionReleaseDelay = Duration(milliseconds: 140);
  final TransformationController _transform = TransformationController();
  Timer? _interactionRelease;
  bool _isTransforming = false;
  bool _isNavigating = false;
  BaseCampFacility? _selectedFacility;
  late final AnimationController _selectionPulse;
  late final AnimationController _personnelTimeline;

  @override
  void initState() {
    super.initState();
    _selectionPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _personnelTimeline = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _interactionRelease?.cancel();
    _selectionPulse.dispose();
    _personnelTimeline.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _beginInteraction(ScaleStartDetails _) {
    _interactionRelease?.cancel();
    _isTransforming = true;
  }

  void _endInteraction(ScaleEndDetails _) {
    _interactionRelease?.cancel();
    _interactionRelease = Timer(_interactionReleaseDelay, () {
      if (mounted) setState(() => _isTransforming = false);
    });
  }

  void _reset() {
    _interactionRelease?.cancel();
    setState(() {
      _isTransforming = false;
      _transform.value = Matrix4.identity();
    });
  }

  void _openFacility(BaseCampFacility facility) {
    if (_isTransforming) return;
    setState(() => _selectedFacility = facility);
  }

  void _clearSelection() {
    if (_isNavigating) return;
    setState(() => _selectedFacility = null);
  }

  void _confirmSelection() {
    final facility = _selectedFacility;
    if (facility == null || _isNavigating) return;
    setState(() => _isNavigating = true);
    widget.onFacilityPressed(facility);
    if (mounted) {
      setState(() {
        _selectedFacility = null;
        _isNavigating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final selectedFacility = _selectedFacility;
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                key: const ValueKey('new-theme-base-camp-map'),
                transformationController: _transform,
                minScale: 1,
                maxScale: 2.4,
                boundaryMargin: EdgeInsets.zero,
                constrained: true,
                panEnabled: true,
                scaleEnabled: true,
                onInteractionStart: _beginInteraction,
                onInteractionEnd: _endInteraction,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        const Image(
                          image: AssetImage(baseCampMapAsset),
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        ),
                        IgnorePointer(
                          child: RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _personnelTimeline,
                              builder: (context, _) => CustomPaint(
                                key: const ValueKey(
                                  'new-theme-base-camp-personnel',
                                ),
                                painter: _BaseCampPersonnelPainter(
                                  elapsed: reducedMotion
                                      ? Duration.zero
                                      : Duration(
                                          milliseconds:
                                              (_personnelTimeline.value * 30000)
                                                  .round(),
                                        ),
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                        if (selectedFacility != null)
                          IgnorePointer(
                            child: RepaintBoundary(
                              child: AnimatedBuilder(
                                animation: _selectionPulse,
                                builder: (context, _) => CustomPaint(
                                  key: const ValueKey(
                                    'new-theme-base-camp-selection-frame',
                                  ),
                                  painter: _FacilitySelectionFramePainter(
                                    facility: selectedFacility,
                                    pulse: reducedMotion
                                        ? 0
                                        : _selectionPulse.value,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                        for (final facility in baseCampFacilities)
                          _BaseCampFacilityTarget(
                            facility: facility,
                            mapSize: size,
                            onPressed: () => _openFacility(facility),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Tooltip(
                  message: 'Reset map framing',
                  child: IconButton.filledTonal(
                    key: const ValueKey('new-theme-base-camp-reset'),
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh),
                  ).actionableFeedback(role: ActionableFeedbackRole.cursor),
                ),
              ),
              if (selectedFacility != null)
                _FacilityConfirmation(
                  facility: selectedFacility,
                  onNo: _clearSelection,
                  onYes: _confirmSelection,
                  enabled: !_isNavigating,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BaseCampFacilityTarget extends StatelessWidget {
  const _BaseCampFacilityTarget({
    required this.facility,
    required this.mapSize,
    required this.onPressed,
  });

  final BaseCampFacility facility;
  final Size mapSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final width = mapSize.width * facility.size.width;
    final height = mapSize.height * facility.size.height;
    return Positioned(
      key: ValueKey('new-theme-base-camp-facility-${facility.id}'),
      left: mapSize.width * facility.center.dx - width / 2,
      top: mapSize.height * facility.center.dy - height / 2,
      width: width,
      height: height,
      child: Semantics(
        button: true,
        label: '${facility.label} facility',
        child: ActionableFeedbackRegion(
          role: ActionableFeedbackRole.command,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _FacilityConfirmation extends StatelessWidget {
  const _FacilityConfirmation({
    required this.facility,
    required this.onNo,
    required this.onYes,
    required this.enabled,
  });

  final BaseCampFacility facility;
  final VoidCallback onNo;
  final VoidCallback onYes;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 12,
    right: 12,
    bottom: 10,
    child: SafeArea(
      top: false,
      child: Semantics(
        container: true,
        label: 'Facility navigation confirmation',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE9142026),
            border: Border.all(
              color: const Color(0xFF68E8F2).withValues(alpha: .65),
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x5540C9DC),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: DefaultTextStyle(
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: const Color(0xFFDDFBFF),
                      height: 1.25,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('BASE CAMP / FACILITY SELECT'),
                        const SizedBox(height: 2),
                        Text(
                          facility.label,
                          style: Theme.of(context).textTheme.titleSmall!
                              .copyWith(
                                color: const Color(0xFF68E8F2),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const Text('この施設へ移動しますか？'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ConfirmationButton(
                  key: const ValueKey('new-theme-base-camp-confirm-no'),
                  label: 'NO',
                  onPressed: enabled ? onNo : null,
                ),
                const SizedBox(width: 6),
                _ConfirmationButton(
                  key: const ValueKey('new-theme-base-camp-confirm-yes'),
                  label: 'YES',
                  highlighted: true,
                  onPressed: enabled ? onYes : null,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ConfirmationButton extends StatelessWidget {
  const _ConfirmationButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.highlighted = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    height: 44,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: highlighted
            ? const Color(0xFF03161A)
            : const Color(0xFFB9F7FF),
        backgroundColor: highlighted
            ? const Color(0xFF68E8F2)
            : const Color(0x182E9DAC),
        side: const BorderSide(color: Color(0xFF68E8F2)),
        padding: EdgeInsets.zero,
        textStyle: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    ).actionableFeedback(role: ActionableFeedbackRole.cursor),
  );
}

class _FacilitySelectionFramePainter extends CustomPainter {
  const _FacilitySelectionFramePainter({
    required this.facility,
    required this.pulse,
  });

  final BaseCampFacility facility;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final corners = facility
        .corners()
        .map(
          (corner) => Offset(corner.dx * size.width, corner.dy * size.height),
        )
        .toList(growable: false);
    final path = Path()..addPolygon(corners, true);
    final intensity =
        .55 + .45 * ((1 + math.sin(pulse * math.pi * 2)) / 2);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF68E8F2).withValues(alpha: .18 * intensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF68E8F2).withValues(
          alpha: .75 + .25 * intensity,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final cornerAccent = Paint()
      ..color = const Color(0xFFE0FCFF)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.square;
    for (var index = 0; index < corners.length; index++) {
      final current = corners[index];
      final next = corners[(index + 1) % corners.length];
      final previous = corners[(index - 1 + corners.length) % corners.length];
      canvas.drawLine(current, Offset.lerp(current, next, .13)!, cornerAccent);
      canvas.drawLine(
        current,
        Offset.lerp(current, previous, .13)!,
        cornerAccent,
      );
    }
  }

  @override
  bool shouldRepaint(_FacilitySelectionFramePainter oldDelegate) =>
      oldDelegate.facility != facility || oldDelegate.pulse != pulse;
}

@immutable
class BaseCampPersonnelPose {
  const BaseCampPersonnelPose({
    required this.position,
    required this.direction,
    required this.isMoving,
  });

  final Offset position;
  final double direction;
  final bool isMoving;
}

/// Deterministic, normalised route sampler.  Keeping it public gives the
/// widget tests a stable way to verify continuity without inspecting pixels.
BaseCampPersonnelPose baseCampPersonnelPose(String id, Duration elapsed) {
  final second = elapsed.inMilliseconds / 1000;
  switch (id) {
    case 'soldier-a':
      return _routePose(
        second,
        18,
        const Offset(.395, .505),
        const Offset(.535, .455),
        7,
        10,
        18,
      );
    case 'soldier-b':
      return _routePose(
        second + 5.5,
        24,
        const Offset(.435, .355),
        const Offset(.565, .395),
        8,
        12,
        20,
      );
    case 'soldier-c':
      return _routePose(
        second + 11,
        21,
        const Offset(.625, .680),
        const Offset(.755, .605),
        8,
        11,
        18,
      );
    case 'jeep':
      return _routePose(
        second + 15,
        30,
        const Offset(.345, .535),
        const Offset(.570, .465),
        8,
        12,
        22,
      );
    default:
      throw ArgumentError.value(id, 'id', 'Unknown Base Camp personnel route');
  }
}

BaseCampPersonnelPose _routePose(
  double seconds,
  double period,
  Offset start,
  Offset end,
  double outboundEnd,
  double returnStart,
  double returnEnd,
) {
  final local = seconds % period;
  if (local < outboundEnd) {
    final progress = local / outboundEnd;
    return BaseCampPersonnelPose(
      position: Offset.lerp(start, end, progress)!,
      direction: (end - start).direction,
      isMoving: true,
    );
  }
  if (local < returnStart) {
    return BaseCampPersonnelPose(
      position: end,
      direction: (end - start).direction,
      isMoving: false,
    );
  }
  if (local < returnEnd) {
    final progress = (local - returnStart) / (returnEnd - returnStart);
    return BaseCampPersonnelPose(
      position: Offset.lerp(end, start, progress)!,
      direction: (start - end).direction,
      isMoving: true,
    );
  }
  return BaseCampPersonnelPose(
    position: start,
    direction: (end - start).direction,
    isMoving: false,
  );
}

class _BaseCampPersonnelPainter extends CustomPainter {
  const _BaseCampPersonnelPainter({required this.elapsed});

  final Duration elapsed;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 650;
    _paintSoldier(canvas, size, unit, 'soldier-a');
    _paintSoldier(canvas, size, unit, 'soldier-b');
    _paintSoldier(canvas, size, unit, 'soldier-c');
    _paintJeep(canvas, size, unit);
  }

  void _paintSoldier(Canvas canvas, Size size, double unit, String id) {
    final pose = baseCampPersonnelPose(id, elapsed);
    final position = Offset(
      pose.position.dx * size.width,
      pose.position.dy * size.height,
    );
    final phase = pose.isMoving
        ? (elapsed.inMilliseconds / 650) * math.pi * 2
        : 0.0;
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(pose.direction + math.pi / 2);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, 4.5 * unit),
        width: 10 * unit,
        height: 3.2 * unit,
      ),
      Paint()..color = const Color(0x88151A14),
    );
    final limb = math.sin(phase) * 2.4 * unit;
    final dark = Paint()..color = const Color(0xFF353D2C);
    final khaki = Paint()..color = const Color(0xFF8A8060);
    final olive = Paint()..color = const Color(0xFF626B45);
    final boot = Paint()..color = const Color(0xFF151A14);
    canvas.drawLine(
      Offset(-2.2 * unit, 2 * unit),
      Offset(-2.8 * unit + limb, 6.2 * unit),
      dark..strokeWidth = 1.6 * unit,
    );
    canvas.drawLine(
      Offset(2.2 * unit, 2 * unit),
      Offset(2.8 * unit - limb, 6.2 * unit),
      dark..strokeWidth = 1.6 * unit,
    );
    canvas.drawCircle(Offset(-2.8 * unit + limb, 6.2 * unit), .9 * unit, boot);
    canvas.drawCircle(Offset(2.8 * unit - limb, 6.2 * unit), .9 * unit, boot);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: 6.4 * unit,
          height: 7.6 * unit,
        ),
        (1.3 * unit).toRadius(),
      ),
      khaki,
    );
    canvas.drawLine(
      Offset(-2.7 * unit, -.5 * unit),
      Offset(-4.8 * unit - limb, 2.3 * unit),
      olive..strokeWidth = 1.4 * unit,
    );
    canvas.drawLine(
      Offset(2.7 * unit, -.5 * unit),
      Offset(4.8 * unit + limb, 2.3 * unit),
      olive..strokeWidth = 1.4 * unit,
    );
    canvas.drawCircle(Offset(0, -5.0 * unit), 2.9 * unit, olive);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(0, -5.9 * unit),
        width: 5.2 * unit,
        height: 1.5 * unit,
      ),
      dark,
    );
    canvas.restore();
  }

  void _paintJeep(Canvas canvas, Size size, double unit) {
    final pose = baseCampPersonnelPose('jeep', elapsed);
    final position = Offset(
      pose.position.dx * size.width,
      pose.position.dy * size.height,
    );
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(pose.direction);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, 5 * unit),
        width: 34 * unit,
        height: 8 * unit,
      ),
      Paint()..color = const Color(0x88151A14),
    );
    final body = Paint()..color = const Color(0xFF626B45);
    final side = Paint()..color = const Color(0xFF353D2C);
    final khaki = Paint()..color = const Color(0xFF8A8060);
    final window = Paint()..color = const Color(0xFF39474A);
    final tyre = Paint()..color = const Color(0xFF151A14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: 32 * unit,
          height: 12 * unit,
        ),
        (2 * unit).toRadius(),
      ),
      body,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-5 * unit, -6 * unit)
        ..lineTo(8 * unit, -6 * unit)
        ..lineTo(11 * unit, -1 * unit)
        ..lineTo(-8 * unit, -1 * unit)
        ..close(),
      khaki,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-3 * unit, -5 * unit, 9 * unit, 3.3 * unit),
        (1 * unit).toRadius(),
      ),
      window,
    );
    canvas.drawRect(
      Rect.fromLTWH(-15 * unit, 2 * unit, 30 * unit, 3.2 * unit),
      side,
    );
    for (final x in <double>[-10, 10]) {
      canvas.drawCircle(Offset(x * unit, 5 * unit), 3.2 * unit, tyre);
      canvas.drawCircle(Offset(x * unit, 5 * unit), 1.25 * unit, khaki);
    }
    canvas.drawRect(
      Rect.fromLTWH(13 * unit, -3 * unit, 3 * unit, 4 * unit),
      khaki,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BaseCampPersonnelPainter oldDelegate) =>
      oldDelegate.elapsed != elapsed;
}

extension on double {
  Radius toRadius() => Radius.circular(this);
}
