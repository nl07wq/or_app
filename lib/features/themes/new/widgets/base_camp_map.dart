import 'dart:async';

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
  });

  final String id;
  final String label;
  final Offset center;
  final Size size;
}

const baseCampFacilities = <BaseCampFacility>[
  BaseCampFacility(
    id: 'status',
    label: 'STATUS',
    center: Offset(.235, .355),
    size: Size(.24, .22),
  ),
  BaseCampFacility(
    id: 'food',
    label: 'FOOD',
    center: Offset(.500, .270),
    size: Size(.25, .20),
  ),
  BaseCampFacility(
    id: 'training',
    label: 'TRAINING',
    center: Offset(.785, .345),
    size: Size(.24, .24),
  ),
  BaseCampFacility(
    id: 'activity',
    label: 'ACTIVITY',
    center: Offset(.285, .630),
    size: Size(.25, .22),
  ),
  BaseCampFacility(
    id: 'command-center',
    label: 'COMMAND CENTER',
    center: Offset(.705, .640),
    size: Size(.28, .25),
  ),
];

class BaseCampMap extends StatefulWidget {
  const BaseCampMap({super.key, required this.onFacilityPressed});

  final ValueChanged<BaseCampFacility> onFacilityPressed;

  @override
  State<BaseCampMap> createState() => _BaseCampMapState();
}

class _BaseCampMapState extends State<BaseCampMap> {
  static const _interactionReleaseDelay = Duration(milliseconds: 140);
  final TransformationController _transform = TransformationController();
  Timer? _interactionRelease;
  bool _isTransforming = false;

  @override
  void dispose() {
    _interactionRelease?.cancel();
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
    widget.onFacilityPressed(facility);
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
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
          ],
        ),
      ),
    ),
  );
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
