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

  static double normalizedRelativeScale(double value) =>
      value.clamp(1.0, 5.0).toDouble();

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
  }) => Offset(
    candidate.dx
        .clamp(viewport.right - imageSize.width, viewport.left)
        .toDouble(),
    candidate.dy
        .clamp(viewport.bottom - imageSize.height, viewport.top)
        .toDouble(),
  );

  static Offset limitWithElasticity({
    required Rect viewport,
    required Size imageSize,
    required Offset candidate,
    required double overscroll,
  }) {
    final minX = viewport.right - imageSize.width;
    final maxX = viewport.left;
    final minY = viewport.bottom - imageSize.height;
    final maxY = viewport.top;
    return Offset(
      candidate.dx
          .clamp(
            (minX < maxX ? minX : maxX) - overscroll,
            (minX > maxX ? minX : maxX) + overscroll,
          )
          .toDouble(),
      candidate.dy
          .clamp(
            (minY < maxY ? minY : maxY) - overscroll,
            (minY > maxY ? minY : maxY) + overscroll,
          )
          .toDouble(),
    );
  }
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
                        .clamp(.85, 5.0)
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
                    setState(() {
                      _scale = next;
                      _pan =
                          FoodManualCropInteraction.limitWithElasticity(
                            viewport: viewport,
                            imageSize: _imageSize(nextActualScale),
                            candidate: nextOffset,
                            overscroll: _overscroll(viewport),
                          ) -
                          initial;
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
                          child: Transform.translate(
                            offset: imageOffset,
                            child: SizedBox(
                              width: widget.dimensions.width * actualScale,
                              height: widget.dimensions.height * actualScale,
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

  double _baseScale(Rect viewport) => [
    viewport.width / widget.dimensions.width,
    viewport.height / widget.dimensions.height,
  ].reduce((a, b) => a > b ? a : b);

  Offset _initialImageOffset(Rect canvas, double scale) => Offset(
    canvas.center.dx - widget.dimensions.width * scale / 2,
    canvas.center.dy - widget.dimensions.height * scale / 2,
  );

  Size _imageSize(double scale) =>
      Size(widget.dimensions.width * scale, widget.dimensions.height * scale);

  double _overscroll(Rect viewport) =>
      (Size(viewport.width, viewport.height).shortestSide * .08)
          .clamp(48.0, 72.0)
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
      return;
    }
    _snapStartScale = _scale;
    _snapEndScale = normalizedScale;
    _snapStartPan = _pan;
    _snapEndPan = targetPan;
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
