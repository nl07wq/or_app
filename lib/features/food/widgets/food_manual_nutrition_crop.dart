import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../services/food_input_capture_gateway.dart';

/// Maps the displayed crop viewport back onto decoded original pixels.
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

/// Pure display-space interaction math for the user-adjustable crop viewport.
///
/// The image offset is its displayed top-left corner. Keeping this separate
/// from original-pixel extraction makes direct pan and focal-point zoom
/// deterministic and testable.
class FoodManualCropInteraction {
  const FoodManualCropInteraction._();

  /// Keeps a small valid source-pixel border around the fixed crop viewport
  /// even at the user's minimum relative zoom. This creates persistent pan
  /// travel on the axis that mathematical cover would otherwise lock.
  /// A centered image needs twice this amount as total over-coverage: ten
  /// percent of the viewport remains available from center toward each edge.
  /// This gives a usable persistent pan range without ever exposing pixels
  /// outside the source image.
  static const minimumPersistentTravelPerSideFraction = .10;
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

  static const minimumViewportWidth = 96.0;
  static const minimumViewportHeight = 72.0;

  /// Keeps an independently sized crop rectangle usable inside its canvas.
  /// The selected rectangle is also the only rectangle transformed to source
  /// pixels at confirmation time.
  static Rect clampViewport({required Rect canvas, required Rect candidate}) {
    final width = candidate.width
        .clamp(minimumViewportWidth, canvas.width)
        .toDouble();
    final height = candidate.height
        .clamp(minimumViewportHeight, canvas.height)
        .toDouble();
    final left = candidate.left.clamp(canvas.left, canvas.right - width);
    final top = candidate.top.clamp(canvas.top, canvas.bottom - height);
    return Rect.fromLTWH(left.toDouble(), top.toDouble(), width, height);
  }
}

enum _CropViewportEdge { left, top, right, bottom }

/// Ephemeral gesture state. Updating this notifier repaints only the crop
/// canvas; the app bar, instructions, and confirmation controls remain out of
/// the pointer-move rebuild path.
class _CropInteractionState {
  const _CropInteractionState({
    this.scale = 1,
    this.pan = Offset.zero,
    this.viewport,
  });

  final double scale;
  final Offset pan;
  final Rect? viewport;

  _CropInteractionState copyWith({
    double? scale,
    Offset? pan,
    Rect? viewport,
  }) => _CropInteractionState(
    scale: scale ?? this.scale,
    pan: pan ?? this.pan,
    viewport: viewport ?? this.viewport,
  );
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
}

Future<FoodCapturedImage?> showManualNutritionCrop({
  required BuildContext context,
  required FoodManualNutritionCropGateway gateway,
  required FoodCapturedImage image,
}) async {
  return Navigator.of(context).push<FoodCapturedImage>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ManualNutritionCropPage(gateway: gateway, image: image),
    ),
  );
}

class _ManualNutritionCropPage extends StatefulWidget {
  const _ManualNutritionCropPage({required this.gateway, required this.image});

  final FoodManualNutritionCropGateway gateway;
  final FoodCapturedImage image;

  @override
  State<_ManualNutritionCropPage> createState() =>
      _ManualNutritionCropPageState();
}

class _ManualNutritionCropPageState extends State<_ManualNutritionCropPage> {
  final GlobalKey _cropCanvasKey = GlobalKey();
  final ValueNotifier<_CropInteractionState> _interaction = ValueNotifier(
    const _CropInteractionState(),
  );
  ImageProvider<Object>? _previewImageProvider;
  FoodNutritionCropPreview? _preview;
  double _startScale = 1;
  Offset _startImageOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;
  bool _previewImageDrawable = false;
  bool _previewLoadFailed = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _preparePreview();
  }

  @override
  void dispose() {
    _interaction.dispose();
    super.dispose();
  }

  FoodImageDimensions get _dimensions => _preview!.originalDimensions;

  Future<void> _preparePreview() async {
    try {
      final preview = await widget.gateway.prepareNutritionCropPreview(
        widget.image,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        // Keep one preview provider for the full crop session. Gesture frames
        // never recreate a web image resource or decode the original again.
        _previewImageProvider = NetworkImage(preview.previewDataUrl);
      });
    } catch (_) {
      if (mounted) setState(() => _previewLoadFailed = true);
    }
  }

  void _markPreviewImageDrawable() {
    if (_previewImageDrawable) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_previewImageDrawable) {
        setState(() => _previewImageDrawable = true);
      }
    });
  }

  void _markPreviewImageFailed() {
    if (_previewLoadFailed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_previewLoadFailed) {
        setState(() => _previewLoadFailed = true);
      }
    });
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
            child: _preview == null
                ? _CropImageLoadingState(failed: _previewLoadFailed)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return ValueListenableBuilder<_CropInteractionState>(
                        valueListenable: _interaction,
                        builder: (context, interaction, _) {
                          final canvas = Rect.fromLTWH(
                            0,
                            0,
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          final viewport = _viewportFor(canvas);
                          final baseScale = _baseScale(viewport);
                          final actualScale = baseScale * interaction.scale;
                          final imageOffset =
                              _initialImageOffset(canvas, actualScale) +
                              interaction.pan;
                          return GestureDetector(
                            key: const ValueKey(
                              'manual-nutrition-crop-gesture-area',
                            ),
                            onScaleStart: (details) {
                              _startScale = interaction.scale;
                              _startImageOffset = imageOffset;
                              _startFocalPoint = details.localFocalPoint;
                            },
                            onScaleUpdate: (details) => _updateImageGesture(
                              details: details,
                              canvas: canvas,
                              viewport: viewport,
                              baseScale: baseScale,
                            ),
                            onScaleEnd: (_) => _normalizeAfterInteraction(
                              canvas: canvas,
                              viewport: viewport,
                              baseScale: baseScale,
                            ),
                            child: RepaintBoundary(
                              child: Stack(
                                key: _cropCanvasKey,
                                fit: StackFit.expand,
                                children: [
                                  ColoredBox(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                  ),
                                  _CropSourceImage(
                                    dimensions: _dimensions,
                                    imageProvider: _previewImageProvider!,
                                    baseScale: baseScale,
                                    relativeScale: interaction.scale,
                                    imageOffset: imageOffset,
                                    onDrawable: _markPreviewImageDrawable,
                                    onFailed: _markPreviewImageFailed,
                                  ),
                                  _CropMask(viewport: viewport),
                                  if (!_previewImageDrawable)
                                    Positioned.fill(
                                      child: _CropImageLoadingState(
                                        failed: _previewLoadFailed,
                                      ),
                                    ),
                                  Positioned.fill(
                                    child: _CropViewportControls(
                                      viewport: viewport,
                                      onMove: (delta) => _moveViewport(
                                        canvas: canvas,
                                        viewport: viewport,
                                        delta: delta,
                                      ),
                                      onResize: (edge, delta) =>
                                          _resizeViewport(
                                            canvas: canvas,
                                            viewport: viewport,
                                            edge: edge,
                                            delta: delta,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text('DRAG IMAGE TO PAN • PINCH TO ZOOM • ADJUST FRAME'),
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

  Rect _viewportFor(Rect canvas) {
    final defaultViewport = Rect.fromCenter(
      center: canvas.center,
      width: canvas.width * .88,
      height: canvas.height * .60,
    );
    return FoodManualCropInteraction.clampViewport(
      canvas: canvas,
      candidate: _interaction.value.viewport ?? defaultViewport,
    );
  }

  void _updateImageGesture({
    required ScaleUpdateDetails details,
    required Rect canvas,
    required Rect viewport,
    required double baseScale,
  }) {
    final next = (_startScale * details.scale).clamp(1.0, 5.0).toDouble();
    final nextActualScale = baseScale * next;
    // Map the source point under the gesture's initial focal point to its
    // current focal point. With one finger this is direct finger-delta pan.
    final nextOffset = FoodManualCropInteraction.offsetForGesture(
      startImageOffset: _startImageOffset,
      startFocalPoint: _startFocalPoint,
      currentFocalPoint: details.localFocalPoint,
      startScale: baseScale * _startScale,
      currentScale: nextActualScale,
    );
    final initial = _initialImageOffset(canvas, nextActualScale);
    final acceptedOffset = FoodManualCropInteraction.translationBounds(
      viewport: viewport,
      imageSize: _imageSize(nextActualScale),
    ).clamp(nextOffset);
    _interaction.value = _interaction.value.copyWith(
      scale: next,
      pan: acceptedOffset - initial,
    );
  }

  void _moveViewport({
    required Rect canvas,
    required Rect viewport,
    required Offset delta,
  }) {
    _setViewport(
      canvas: canvas,
      previous: viewport,
      candidate: viewport.shift(delta),
    );
  }

  void _resizeViewport({
    required Rect canvas,
    required Rect viewport,
    required _CropViewportEdge edge,
    required Offset delta,
  }) {
    final candidate = switch (edge) {
      _CropViewportEdge.left => Rect.fromLTRB(
        viewport.left + delta.dx,
        viewport.top,
        viewport.right,
        viewport.bottom,
      ),
      _CropViewportEdge.top => Rect.fromLTRB(
        viewport.left,
        viewport.top + delta.dy,
        viewport.right,
        viewport.bottom,
      ),
      _CropViewportEdge.right => Rect.fromLTRB(
        viewport.left,
        viewport.top,
        viewport.right + delta.dx,
        viewport.bottom,
      ),
      _CropViewportEdge.bottom => Rect.fromLTRB(
        viewport.left,
        viewport.top,
        viewport.right,
        viewport.bottom + delta.dy,
      ),
    };
    _setViewport(canvas: canvas, previous: viewport, candidate: candidate);
  }

  void _setViewport({
    required Rect canvas,
    required Rect previous,
    required Rect candidate,
  }) {
    final next = FoodManualCropInteraction.clampViewport(
      canvas: canvas,
      candidate: candidate,
    );
    final previousBaseScale = _baseScale(previous);
    final interaction = _interaction.value;
    final previousActualScale = previousBaseScale * interaction.scale;
    final currentOffset =
        _initialImageOffset(canvas, previousActualScale) + interaction.pan;
    final nextBaseScale = _baseScale(next);
    final nextRelativeScale = (previousActualScale / nextBaseScale)
        .clamp(1.0, 5.0)
        .toDouble();
    final nextActualScale = nextBaseScale * nextRelativeScale;
    final acceptedOffset = FoodManualCropInteraction.clampToCoverage(
      viewport: next,
      imageSize: _imageSize(nextActualScale),
      candidate: currentOffset,
    );
    _interaction.value = interaction.copyWith(
      viewport: next,
      scale: nextRelativeScale,
      pan: acceptedOffset - _initialImageOffset(canvas, nextActualScale),
    );
  }

  double _baseScale(Rect viewport) =>
      FoodManualCropInteraction.minimumBaseScale(
        viewport: viewport,
        source: _dimensions,
      );

  Offset _initialImageOffset(Rect canvas, double scale) => Offset(
    canvas.center.dx - _dimensions.width * scale / 2,
    canvas.center.dy - _dimensions.height * scale / 2,
  );

  Size _imageSize(double scale) =>
      Size(_dimensions.width * scale, _dimensions.height * scale);

  void _normalizeAfterInteraction({
    required Rect canvas,
    required Rect viewport,
    required double baseScale,
  }) {
    final interaction = _interaction.value;
    final currentScale = baseScale * interaction.scale;
    final normalizedScale = FoodManualCropInteraction.normalizedRelativeScale(
      interaction.scale,
    );
    final targetScale = baseScale * normalizedScale;
    final currentOffset =
        _initialImageOffset(canvas, currentScale) + interaction.pan;
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
    _interaction.value = interaction.copyWith(
      scale: normalizedScale,
      pan: targetPan,
    );
  }

  Future<void> _confirmCrop() async {
    final box = _cropCanvasKey.currentContext!.findRenderObject()! as RenderBox;
    final canvas = Offset.zero & box.size;
    final viewport = _viewportFor(canvas);
    final baseScale = _baseScale(viewport);
    final interaction = _interaction.value;
    final currentScale = baseScale * interaction.scale;
    final normalizedScale = FoodManualCropInteraction.normalizedRelativeScale(
      interaction.scale,
    );
    final actualScale = baseScale * normalizedScale;
    final currentOffset =
        _initialImageOffset(canvas, currentScale) + interaction.pan;
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
      source: _dimensions,
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

class _CropSourceImage extends StatelessWidget {
  const _CropSourceImage({
    required this.dimensions,
    required this.imageProvider,
    required this.baseScale,
    required this.relativeScale,
    required this.imageOffset,
    required this.onDrawable,
    required this.onFailed,
  });

  final FoodImageDimensions dimensions;
  final ImageProvider<Object> imageProvider;
  final double baseScale;
  final double relativeScale;
  final Offset imageOffset;
  final VoidCallback onDrawable;
  final VoidCallback onFailed;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: RepaintBoundary(
      child: Transform(
        key: const ValueKey('manual-nutrition-crop-image-transform'),
        transform: Matrix4.identity()
          ..translateByDouble(imageOffset.dx, imageOffset.dy, 0, 1)
          ..scaleByDouble(relativeScale, relativeScale, 1, 1),
        // Transform receives the canvas's tight constraints. Release them for
        // the stable decoded bitmap so paint geometry and source mapping share
        // the exact same base dimensions.
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          maxWidth: double.infinity,
          minHeight: 0,
          maxHeight: double.infinity,
          child: SizedBox(
            width: dimensions.width * baseScale,
            height: dimensions.height * baseScale,
            child: KeyedSubtree(
              key: const ValueKey('manual-nutrition-crop-source-image'),
              child: Image(
                image: imageProvider,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                filterQuality: FilterQuality.high,
                frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
                  if (frame != null || wasSynchronouslyLoaded) onDrawable();
                  return child;
                },
                errorBuilder: (_, _, _) {
                  onFailed();
                  return const ColoredBox(color: Colors.transparent);
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CropImageLoadingState extends StatelessWidget {
  const _CropImageLoadingState({this.failed = false});

  final bool failed;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!failed) const Icon(Icons.image_outlined, size: 20),
          if (!failed) const SizedBox(height: AppSpacing.sm),
          Text(failed ? 'IMAGE UNAVAILABLE' : 'LOADING IMAGE...'),
        ],
      ),
    ),
  );
}

class _CropViewportControls extends StatelessWidget {
  const _CropViewportControls({
    required this.viewport,
    required this.onMove,
    required this.onResize,
  });

  final Rect viewport;
  final ValueChanged<Offset> onMove;
  final void Function(_CropViewportEdge edge, Offset delta) onResize;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Positioned(
        left: viewport.center.dx - 52,
        top: viewport.top + 6,
        width: 104,
        height: 28,
        child: _CropViewportHandle(
          key: const ValueKey('manual-nutrition-crop-move-handle'),
          semanticLabel: 'Move crop area',
          icon: Icons.open_with,
          onPanUpdate: onMove,
        ),
      ),
      Positioned(
        left: viewport.left - 14,
        top: viewport.center.dy - 14,
        width: 28,
        height: 28,
        child: _CropViewportHandle(
          key: const ValueKey('manual-nutrition-crop-resize-left'),
          semanticLabel: 'Resize crop width',
          icon: Icons.drag_handle,
          onPanUpdate: (delta) => onResize(_CropViewportEdge.left, delta),
        ),
      ),
      Positioned(
        left: viewport.right - 14,
        top: viewport.center.dy - 14,
        width: 28,
        height: 28,
        child: _CropViewportHandle(
          key: const ValueKey('manual-nutrition-crop-resize-right'),
          semanticLabel: 'Resize crop width',
          icon: Icons.drag_handle,
          onPanUpdate: (delta) => onResize(_CropViewportEdge.right, delta),
        ),
      ),
      Positioned(
        left: viewport.center.dx - 14,
        top: viewport.top - 14,
        width: 28,
        height: 28,
        child: _CropViewportHandle(
          key: const ValueKey('manual-nutrition-crop-resize-top'),
          semanticLabel: 'Resize crop height',
          icon: Icons.drag_handle,
          rotate: true,
          onPanUpdate: (delta) => onResize(_CropViewportEdge.top, delta),
        ),
      ),
      Positioned(
        left: viewport.center.dx - 14,
        top: viewport.bottom - 14,
        width: 28,
        height: 28,
        child: _CropViewportHandle(
          key: const ValueKey('manual-nutrition-crop-resize-bottom'),
          semanticLabel: 'Resize crop height',
          icon: Icons.drag_handle,
          rotate: true,
          onPanUpdate: (delta) => onResize(_CropViewportEdge.bottom, delta),
        ),
      ),
    ],
  );
}

class _CropViewportHandle extends StatelessWidget {
  const _CropViewportHandle({
    required super.key,
    required this.semanticLabel,
    required this.icon,
    required this.onPanUpdate,
    this.rotate = false,
  });

  final String semanticLabel;
  final IconData icon;
  final ValueChanged<Offset> onPanUpdate;
  final bool rotate;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) => onPanUpdate(details.delta),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Transform.rotate(
          angle: rotate ? 1.5707963267948966 : 0,
          child: Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    ),
  );
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
