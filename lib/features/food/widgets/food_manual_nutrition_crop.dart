import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../services/food_input_capture_gateway.dart';

/// Maps the fixed displayed crop viewport back onto decoded original pixels.
/// It intentionally has no OCR knowledge so the conversion is deterministic
/// and directly testable without a rendered screenshot.
class FoodManualCropTransform {
  FoodManualCropTransform({
    required this.source,
    required this.viewport,
    required this.scale,
    required this.imageOffset,
  });

  final FoodImageDimensions source;
  final Rect viewport;
  final double scale;
  final Offset imageOffset;

  Rect get sourceRect =>
      Rect.fromLTRB(
        (viewport.left - imageOffset.dx) / scale,
        (viewport.top - imageOffset.dy) / scale,
        (viewport.right - imageOffset.dx) / scale,
        (viewport.bottom - imageOffset.dy) / scale,
      ).intersect(
        Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      );
}

/// Pure display-space interaction math for the fixed crop viewport.
///
/// The image offset is its displayed top-left corner. Keeping this separate
/// from original-pixel extraction makes direct pan and focal-point zoom
/// deterministic and testable.
class FoodManualCropInteraction {
  const FoodManualCropInteraction._();

  /// Keeps a small valid source-pixel border around the fixed crop viewport
  /// even at the user's minimum relative zoom. This creates persistent pan
  /// travel on the axis that mathematical cover would otherwise lock.
  /// A centered image needs twice this amount as total over-coverage: five
  /// percent of the viewport remains available from center toward each edge.
  static const minimumPersistentTravelPerSideFraction = .05;
  static const minimumOverCoverageFactor =
      1 + minimumPersistentTravelPerSideFraction * 2;

  static double normalizedRelativeScale(double value) =>
      value.clamp(1.0, 5.0).toDouble();

  static double minimumBaseScale({
    required Rect viewport,
    required FoodImageDimensions source,
  }) =>
      [
        viewport.width / source.width,
        viewport.height / source.height,
      ].reduce((a, b) => a > b ? a : b) *
      minimumOverCoverageFactor;

  static Offset offsetForGesture({
    required Offset startImageOffset,
    required Offset startFocalPoint,
    required Offset currentFocalPoint,
    required double startScale,
    required double currentScale,
  }) {
    final scaleRatio = currentScale / startScale;
    return currentFocalPoint -
        (startFocalPoint - startImageOffset) * scaleRatio;
  }

  static Offset offsetForScaleAtFocalPoint({
    required Offset imageOffset,
    required Offset focalPoint,
    required double currentScale,
    required double nextScale,
  }) {
    final scaleRatio = nextScale / currentScale;
    return focalPoint - (focalPoint - imageOffset) * scaleRatio;
  }

  static Offset clampToCoverage({
    required Rect viewport,
    required Size imageSize,
    required Offset candidate,
  }) {
    return translationBounds(
      viewport: viewport,
      imageSize: imageSize,
    ).clamp(candidate);
  }

  /// The displayed image's top-left translation interval that covers the
  /// fixed viewport. Both axes use the same image-vs-viewport geometry; this
  /// prevents a directional offset from limiting one usable source edge.
  static FoodManualCropTranslationBounds translationBounds({
    required Rect viewport,
    required Size imageSize,
  }) => FoodManualCropTranslationBounds.forCoverage(
    viewport: viewport,
    imageSize: imageSize,
  );

  static Offset limitWithElasticity({
    required Rect viewport,
    required Size imageSize,
    required Offset candidate,
    required double overscroll,
  }) {
    final bounds = activeTranslationBounds(
      viewport: viewport,
      imageSize: imageSize,
      overscroll: overscroll,
    );
    // The relative gesture scale never goes below cover scale, so each valid
    // range is finite. Keep a small, symmetric elastic range while fingers
    // are down; strict four-edge coverage is restored on release.
    return Offset(
      candidate.dx.clamp(bounds.minX, bounds.maxX).toDouble(),
      candidate.dy.clamp(bounds.minY, bounds.maxY).toDouble(),
    );
  }

  /// The exact active-gesture interval used by [limitWithElasticity].
  static FoodManualCropTranslationBounds activeTranslationBounds({
    required Rect viewport,
    required Size imageSize,
    required double overscroll,
  }) => translationBounds(
    viewport: viewport,
    imageSize: imageSize,
  ).expandedBy(overscroll);
}

class FoodManualCropTranslationBounds {
  const FoodManualCropTranslationBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  factory FoodManualCropTranslationBounds.forCoverage({
    required Rect viewport,
    required Size imageSize,
  }) {
    double axisMinimum(double viewportEnd, double imageExtent) =>
        viewportEnd - imageExtent;
    double axisMaximum(double viewportStart) => viewportStart;
    return FoodManualCropTranslationBounds(
      minX: axisMinimum(viewport.right, imageSize.width),
      maxX: axisMaximum(viewport.left),
      minY: axisMinimum(viewport.bottom, imageSize.height),
      maxY: axisMaximum(viewport.top),
    );
  }

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  Offset clamp(Offset candidate) => Offset(
    candidate.dx.clamp(minX, maxX).toDouble(),
    candidate.dy.clamp(minY, maxY).toDouble(),
  );

  FoodManualCropTranslationBounds expandedBy(double amount) =>
      FoodManualCropTranslationBounds(
        minX: minX - amount,
        maxX: maxX + amount,
        minY: minY - amount,
        maxY: maxY + amount,
      );
}

Future<FoodCapturedImage?> showManualNutritionCrop({
  required BuildContext context,
  required FoodManualNutritionCropGateway gateway,
  required FoodCapturedImage image,
}) async {
  final dimensions = await gateway.nutritionImageDimensions(image);
  if (!context.mounted) return null;
  return Navigator.of(context).push<FoodCapturedImage>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ManualNutritionCropPage(
        gateway: gateway,
        image: image,
        dimensions: dimensions,
      ),
    ),
  );
}

class _ManualNutritionCropPage extends StatefulWidget {
  const _ManualNutritionCropPage({
    required this.gateway,
    required this.image,
    required this.dimensions,
  });

  final FoodManualNutritionCropGateway gateway;
  final FoodCapturedImage image;
  final FoodImageDimensions dimensions;

  @override
  State<_ManualNutritionCropPage> createState() =>
      _ManualNutritionCropPageState();
}

class _ManualNutritionCropPageState extends State<_ManualNutritionCropPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey _cropCanvasKey = GlobalKey();
  late final ImageProvider<Object> _sourceImageProvider;
  late final AnimationController _snapController;
  double _scale = 1;
  Offset _pan = Offset.zero;
  double _startScale = 1;
  Offset _startImageOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;
  double _snapStartScale = 1;
  double _snapEndScale = 1;
  Offset _snapStartPan = Offset.zero;
  Offset _snapEndPan = Offset.zero;
  _CropActiveSnapshot? _lastActiveSnapshot;
  Offset? _lastReleaseNormalizedOffset;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Keep one provider for the full crop session. Gesture frames must move a
    // decoded image layer, never recreate a web image resource.
    _sourceImageProvider = NetworkImage(widget.image.dataUrl);
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    )..addListener(_applySnapFrame);
  }

  @override
  void dispose() {
    _snapController
      ..removeListener(_applySnapFrame)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('CROP NUTRITION LABEL'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _submitting ? null : () => Navigator.pop(context),
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvas = Rect.fromLTWH(
                  0,
                  0,
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                final viewport = Rect.fromCenter(
                  center: canvas.center,
                  width: canvas.width * .88,
                  height: canvas.height * .60,
                );
                final baseScale = _baseScale(viewport);
                final actualScale = baseScale * _scale;
                final imageOffset =
                    _initialImageOffset(canvas, actualScale) + _pan;
                final overscroll = _overscroll(viewport);
                return GestureDetector(
                  key: const ValueKey('manual-nutrition-crop-gesture-area'),
                  onScaleStart: (details) {
                    _snapController.stop();
                    _startScale = _scale;
                    _startImageOffset = imageOffset;
                    _startFocalPoint = details.localFocalPoint;
                  },
                  onScaleUpdate: (details) {
                    final next = (_startScale * details.scale)
                        .clamp(1.0, 5.0)
                        .toDouble();
                    final nextActualScale = baseScale * next;
                    // Map the source point under the gesture's initial focal
                    // point to its current focal point. With one finger this
                    // reduces exactly to direct pan by the finger delta.
                    final nextOffset =
                        FoodManualCropInteraction.offsetForGesture(
                          startImageOffset: _startImageOffset,
                          startFocalPoint: _startFocalPoint,
                          currentFocalPoint: details.localFocalPoint,
                          startScale: baseScale * _startScale,
                          currentScale: nextActualScale,
                        );
                    final initial = _initialImageOffset(
                      canvas,
                      nextActualScale,
                    );
                    final activeBounds =
                        FoodManualCropInteraction.activeTranslationBounds(
                          viewport: viewport,
                          imageSize: _imageSize(nextActualScale),
                          overscroll: overscroll,
                        );
                    final acceptedOffset =
                        FoodManualCropInteraction.limitWithElasticity(
                          viewport: viewport,
                          imageSize: _imageSize(nextActualScale),
                          candidate: nextOffset,
                          overscroll: overscroll,
                        );
                    setState(() {
                      _scale = next;
                      _pan = acceptedOffset - initial;
                      _lastActiveSnapshot = _CropActiveSnapshot(
                        rawDelta: details.localFocalPoint - _startFocalPoint,
                        candidateOffset: nextOffset,
                        acceptedOffset: acceptedOffset,
                        bounds: activeBounds,
                      );
                    });
                  },
                  onScaleEnd: (_) => _normalizeAfterInteraction(
                    canvas: canvas,
                    viewport: viewport,
                    baseScale: baseScale,
                  ),
                  child: Stack(
                    key: _cropCanvasKey,
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: Theme.of(context).colorScheme.surface),
                      ClipRect(
                        child: RepaintBoundary(
                          key: const ValueKey(
                            'manual-nutrition-crop-image-layer',
                          ),
                          child: Transform(
                            key: const ValueKey(
                              'manual-nutrition-crop-image-transform',
                            ),
                            transform: Matrix4.identity()
                              ..translateByDouble(
                                imageOffset.dx,
                                imageOffset.dy,
                                0,
                                1,
                              )
                              ..scaleByDouble(_scale, _scale, 1, 1),
                            child: SizedBox(
                              // Keep one stable decoded image at base cover
                              // size. The current relative scale is applied by
                              // the same paint transform used for gestures and
                              // four-edge bounds, so a pinch changes rendered
                              // pixels immediately instead of only state.
                              width: widget.dimensions.width * baseScale,
                              height: widget.dimensions.height * baseScale,
                              child: Image(
                                key: const ValueKey(
                                  'manual-nutrition-crop-source-image',
                                ),
                                image: _sourceImageProvider,
                                fit: BoxFit.fill,
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (_, _, _) =>
                                    const ColoredBox(color: Colors.transparent),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _CropMask(viewport: viewport),
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: IgnorePointer(
                          child: _CropGeometryDiagnosticPanel(
                            canvas: canvas,
                            viewport: viewport,
                            source: widget.dimensions,
                            baseScale: baseScale,
                            relativeScale: _scale,
                            actualScale: actualScale,
                            currentOffset: imageOffset,
                            lastActive: _lastActiveSnapshot,
                            lastReleaseNormalizedOffset:
                                _lastReleaseNormalizedOffset,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text('PINCH TO ZOOM • DRAG TO POSITION'),
          ),
          Padding(
            padding: AppSpacing.cardPadding,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('manual-nutrition-crop-cancel'),
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('manual-nutrition-crop-confirm'),
                    onPressed: _submitting ? null : () => _confirmCrop(),
                    child: const Text('USE THIS AREA'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  double _baseScale(Rect viewport) =>
      FoodManualCropInteraction.minimumBaseScale(
        viewport: viewport,
        source: widget.dimensions,
      );

  Offset _initialImageOffset(Rect canvas, double scale) => Offset(
    canvas.center.dx - widget.dimensions.width * scale / 2,
    canvas.center.dy - widget.dimensions.height * scale / 2,
  );

  Size _imageSize(double scale) =>
      Size(widget.dimensions.width * scale, widget.dimensions.height * scale);

  double _overscroll(Rect viewport) =>
      (Size(viewport.width, viewport.height).shortestSide * .35)
          .clamp(96.0, 180.0)
          .toDouble();

  void _normalizeAfterInteraction({
    required Rect canvas,
    required Rect viewport,
    required double baseScale,
  }) {
    final currentScale = baseScale * _scale;
    final normalizedScale = FoodManualCropInteraction.normalizedRelativeScale(
      _scale,
    );
    final targetScale = baseScale * normalizedScale;
    final currentOffset = _initialImageOffset(canvas, currentScale) + _pan;
    final scaledOffset = FoodManualCropInteraction.offsetForScaleAtFocalPoint(
      imageOffset: currentOffset,
      focalPoint: viewport.center,
      currentScale: currentScale,
      nextScale: targetScale,
    );
    final targetOffset = FoodManualCropInteraction.clampToCoverage(
      viewport: viewport,
      imageSize: _imageSize(targetScale),
      candidate: scaledOffset,
    );
    final targetPan = targetOffset - _initialImageOffset(canvas, targetScale);
    if ((_scale - normalizedScale).abs() < .0001 &&
        (_pan - targetPan).distance < .1) {
      setState(() => _lastReleaseNormalizedOffset = targetOffset);
      return;
    }
    _snapStartScale = _scale;
    _snapEndScale = normalizedScale;
    _snapStartPan = _pan;
    _snapEndPan = targetPan;
    _lastReleaseNormalizedOffset = targetOffset;
    _snapController.forward(from: 0);
  }

  void _applySnapFrame() {
    if (!mounted) return;
    final t = Curves.easeOut.transform(_snapController.value);
    setState(() {
      _scale = _snapStartScale + (_snapEndScale - _snapStartScale) * t;
      _pan = Offset.lerp(_snapStartPan, _snapEndPan, t)!;
    });
  }

  Future<void> _confirmCrop() async {
    final box = _cropCanvasKey.currentContext!.findRenderObject()! as RenderBox;
    final canvas = Offset.zero & box.size;
    final viewport = Rect.fromCenter(
      center: canvas.center,
      width: canvas.width * .88,
      height: canvas.height * .60,
    );
    final baseScale = _baseScale(viewport);
    final currentScale = baseScale * _scale;
    final normalizedScale = FoodManualCropInteraction.normalizedRelativeScale(
      _scale,
    );
    final actualScale = baseScale * normalizedScale;
    final currentOffset = _initialImageOffset(canvas, currentScale) + _pan;
    final offset = FoodManualCropInteraction.clampToCoverage(
      viewport: viewport,
      imageSize: _imageSize(actualScale),
      candidate: FoodManualCropInteraction.offsetForScaleAtFocalPoint(
        imageOffset: currentOffset,
        focalPoint: viewport.center,
        currentScale: currentScale,
        nextScale: actualScale,
      ),
    );
    final sourceRect = FoodManualCropTransform(
      source: widget.dimensions,
      viewport: viewport,
      scale: actualScale,
      imageOffset: offset,
    ).sourceRect;
    if (sourceRect.width < 1 || sourceRect.height < 1) return;
    setState(() => _submitting = true);
    try {
      final cropped = await widget.gateway.cropNutritionImage(
        widget.image,
        FoodImageCropRect(
          x: sourceRect.left,
          y: sourceRect.top,
          width: sourceRect.width,
          height: sourceRect.height,
        ),
      );
      if (mounted) Navigator.pop(context, cropped);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _CropActiveSnapshot {
  const _CropActiveSnapshot({
    required this.rawDelta,
    required this.candidateOffset,
    required this.acceptedOffset,
    required this.bounds,
  });

  final Offset rawDelta;
  final Offset candidateOffset;
  final Offset acceptedOffset;
  final FoodManualCropTranslationBounds bounds;
}

class _CropGeometryDiagnosticPanel extends StatelessWidget {
  const _CropGeometryDiagnosticPanel({
    required this.canvas,
    required this.viewport,
    required this.source,
    required this.baseScale,
    required this.relativeScale,
    required this.actualScale,
    required this.currentOffset,
    required this.lastActive,
    required this.lastReleaseNormalizedOffset,
  });

  final Rect canvas;
  final Rect viewport;
  final FoodImageDimensions source;
  final double baseScale;
  final double relativeScale;
  final double actualScale;
  final Offset currentOffset;
  final _CropActiveSnapshot? lastActive;
  final Offset? lastReleaseNormalizedOffset;

  String _number(double? value) =>
      value == null ? '-' : value.toStringAsFixed(1);

  String _pair(Offset? value) =>
      value == null ? '(-, -)' : '(${_number(value.dx)}, ${_number(value.dy)})';

  @override
  Widget build(BuildContext context) {
    final active = lastActive;
    final baseWidth = source.width * baseScale;
    final baseHeight = source.height * baseScale;
    final lines = [
      'CROP GEOMETRY',
      'CANVAS ${_number(canvas.width)}×${_number(canvas.height)}  VIEW ${_number(viewport.width)}×${_number(viewport.height)}',
      'SOURCE ${source.width}×${source.height}  BASE ${_number(baseWidth)}×${_number(baseHeight)}',
      'SCALE b:${_number(baseScale)} r:${_number(relativeScale)} a:${_number(actualScale)}',
      'CURRENT ${_pair(currentOffset)}',
      'ACTIVE raw=${_pair(active?.rawDelta)} candidate=${_pair(active?.candidateOffset)}',
      'bounds x:${_number(active?.bounds.minX)}..${_number(active?.bounds.maxX)}',
      'bounds y:${_number(active?.bounds.minY)}..${_number(active?.bounds.maxY)}',
      'post=${_pair(active?.acceptedOffset)}',
      'RELEASE norm=${_pair(lastReleaseNormalizedOffset)}',
    ];
    return Semantics(
      label: 'Crop geometry diagnostic',
      child: Container(
        key: const ValueKey('manual-nutrition-crop-geometry-diagnostic'),
        constraints: const BoxConstraints(maxWidth: 224),
        padding: const EdgeInsets.all(AppSpacing.xs),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .92),
        child: Text(
          lines.join('\n'),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            height: 1.18,
          ),
        ),
      ),
    );
  }
}

class _CropMask extends StatelessWidget {
  const _CropMask({required this.viewport});
  final Rect viewport;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _CropMaskPainter(viewport, Theme.of(context).colorScheme.primary),
  );
}

class _CropMaskPainter extends CustomPainter {
  const _CropMaskPainter(this.viewport, this.accent);
  final Rect viewport;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path()
      ..addRect(Offset.zero & size)
      ..addRect(viewport)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: .56),
    );
    canvas.drawRect(
      viewport,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent,
    );
  }

  @override
  bool shouldRepaint(_CropMaskPainter oldDelegate) =>
      oldDelegate.viewport != viewport || oldDelegate.accent != accent;
}
