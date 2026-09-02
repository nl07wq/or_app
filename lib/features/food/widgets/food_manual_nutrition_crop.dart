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

class _ManualNutritionCropPageState extends State<_ManualNutritionCropPage> {
  final GlobalKey _cropCanvasKey = GlobalKey();
  double _scale = 1;
  Offset _pan = Offset.zero;
  double _startScale = 1;
  bool _submitting = false;

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
                final imageOffset = _clampedImageOffset(
                  viewport,
                  actualScale,
                  _initialImageOffset(canvas, actualScale) + _pan,
                );
                return GestureDetector(
                  key: const ValueKey('manual-nutrition-crop-gesture-area'),
                  onScaleStart: (details) {
                    _startScale = _scale;
                  },
                  onScaleUpdate: (details) {
                    final next = (_startScale * details.scale).clamp(1.0, 5.0);
                    final scaleRatio = next / _scale;
                    final currentOffset = imageOffset;
                    final nextActualScale = baseScale * next;
                    // Keep the source point below the focal point stable during
                    // pinch, then clamp so crop viewport never exposes blanks.
                    final focal = details.localFocalPoint;
                    final nextOffset =
                        focal - (focal - currentOffset) * scaleRatio;
                    final initial = _initialImageOffset(
                      canvas,
                      nextActualScale,
                    );
                    setState(() {
                      _scale = next;
                      _pan =
                          _clampedImageOffset(
                            viewport,
                            nextActualScale,
                            nextOffset,
                          ) -
                          initial;
                    });
                  },
                  child: Stack(
                    key: _cropCanvasKey,
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: Theme.of(context).colorScheme.surface),
                      ClipRect(
                        child: Transform.translate(
                          offset: imageOffset,
                          child: SizedBox(
                            width: widget.dimensions.width * actualScale,
                            height: widget.dimensions.height * actualScale,
                            child: _image(widget.image.dataUrl),
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

  Offset _clampedImageOffset(Rect viewport, double scale, Offset candidate) {
    final imageWidth = widget.dimensions.width * scale;
    final imageHeight = widget.dimensions.height * scale;
    return Offset(
      candidate.dx.clamp(viewport.right - imageWidth, viewport.left),
      candidate.dy.clamp(viewport.bottom - imageHeight, viewport.top),
    );
  }

  Future<void> _confirmCrop() async {
    final box = _cropCanvasKey.currentContext!.findRenderObject()! as RenderBox;
    final canvas = Offset.zero & box.size;
    final viewport = Rect.fromCenter(
      center: canvas.center,
      width: canvas.width * .88,
      height: canvas.height * .60,
    );
    final actualScale = _baseScale(viewport) * _scale;
    final offset = _clampedImageOffset(
      viewport,
      actualScale,
      _initialImageOffset(canvas, actualScale) + _pan,
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

  Widget _image(String dataUrl) {
    return Image.network(
      dataUrl,
      key: const ValueKey('manual-nutrition-crop-source-image'),
      fit: BoxFit.fill,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Text('IMAGE UNAVAILABLE')),
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
