import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../services/training_history_domain_service.dart';
import '../services/training_recovery_evidence_adapter.dart';

enum SvgBodyMapSide { front, back }

const _assets = {
  SvgBodyMapSide.front: 'assets/body_map/body_map_front.svg',
  SvgBodyMapSide.back: 'assets/body_map/body_map_back.svg',
};

final _documents = <SvgBodyMapSide, Future<SvgBodyMapDocument>>{};

typedef SvgBodyMapPathOverride = Path Function(String id, Path basePath);

const svgBodyMapMuscles = <SvgBodyMapSide, Map<String, MuscleGroup>>{
  SvgBodyMapSide.front: {
    'front-chest-left': MuscleGroup.chest,
    'front-chest-right': MuscleGroup.chest,
    'front-shoulder-left': MuscleGroup.shoulders,
    'front-shoulder-right': MuscleGroup.shoulders,
    'front-biceps-left': MuscleGroup.biceps,
    'front-biceps-right': MuscleGroup.biceps,
    'front-forearm-left': MuscleGroup.forearms,
    'front-forearm-right': MuscleGroup.forearms,
    'front-core': MuscleGroup.core,
    'front-quadriceps-left': MuscleGroup.quadriceps,
    'front-quadriceps-right': MuscleGroup.quadriceps,
  },
  SvgBodyMapSide.back: {
    'back-trapezius': MuscleGroup.trapezius,
    'back-lats-left': MuscleGroup.lats,
    'back-lats-right': MuscleGroup.lats,
    'back-shoulder-left': MuscleGroup.shoulders,
    'back-shoulder-right': MuscleGroup.shoulders,
    'back-triceps-left': MuscleGroup.triceps,
    'back-triceps-right': MuscleGroup.triceps,
    'back-forearm-left': MuscleGroup.forearms,
    'back-forearm-right': MuscleGroup.forearms,
    'back-glutes-left': MuscleGroup.glutes,
    'back-glutes-right': MuscleGroup.glutes,
    'back-hamstrings-left': MuscleGroup.hamstrings,
    'back-hamstrings-right': MuscleGroup.hamstrings,
    'back-calves-left': MuscleGroup.calves,
    'back-calves-right': MuscleGroup.calves,
  },
};

class SvgBodyMapDocument {
  const SvgBodyMapDocument(this.paths);
  final Map<String, Path> paths;
}

Future<SvgBodyMapDocument> loadSvgBodyMap(SvgBodyMapSide side) =>
    _documents.putIfAbsent(
      side,
      () async => parseSvgBodyMap(await rootBundle.loadString(_assets[side]!)),
    );

SvgBodyMapDocument parseSvgBodyMap(String svg) {
  if (svg.contains('<image')) {
    throw const FormatException('Raster SVG embeds are not allowed.');
  }
  final paths = <String, Path>{};
  final matcher = RegExp(
    r'<path\s+id="([^"]+)"\s+d="([^"]+)"\s*/>',
  ).allMatches(svg);
  for (final match in matcher) {
    paths[match.group(1)!] = _SvgPathParser(match.group(2)!).parse();
  }
  if (paths.isEmpty) {
    throw const FormatException('No vector paths found.');
  }
  return SvgBodyMapDocument(Map.unmodifiable(paths));
}

class SvgBodyMapPrototype extends StatefulWidget {
  const SvgBodyMapPrototype({
    super.key,
    required this.side,
    required this.recoveryByMuscle,
    required this.supportMuscles,
    this.previewStatuses = const {},
    this.selectedMuscle,
    this.onSelected,
    this.editMode = false,
    this.selectedRegionId,
    this.onRegionSelected,
    this.pathOverride,
  });
  final SvgBodyMapSide side;
  final Map<MuscleGroup, TrainingRecoveryEvidence> recoveryByMuscle;
  final Set<MuscleGroup> supportMuscles;
  final Map<MuscleGroup, RecoveryStatus> previewStatuses;
  final MuscleGroup? selectedMuscle;
  final ValueChanged<MuscleGroup>? onSelected;

  /// Development-only controls used by the SYSTEM geometry tuner.
  final bool editMode;
  final String? selectedRegionId;
  final ValueChanged<String>? onRegionSelected;
  final SvgBodyMapPathOverride? pathOverride;
  @override
  State<SvgBodyMapPrototype> createState() => _SvgBodyMapPrototypeState();
}

class _SvgBodyMapPrototypeState extends State<SvgBodyMapPrototype> {
  late Future<SvgBodyMapDocument> _document = loadSvgBodyMap(widget.side);
  @override
  void didUpdateWidget(covariant SvgBodyMapPrototype old) {
    super.didUpdateWidget(old);
    if (old.side != widget.side) _document = loadSvgBodyMap(widget.side);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SvgBodyMapDocument>(
    key: ValueKey(widget.side),
    future: _document,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const SizedBox(
          key: ValueKey('svg-body-map-loading'),
          height: 300,
        );
      }
      final document = snapshot.data!;
      return AspectRatio(
        aspectRatio: 200 / 340,
        child: LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            key: ValueKey('svg-body-map-${widget.side.name}'),
            onTapUp: (details) {
              final point = Offset(
                details.localPosition.dx * 200 / constraints.maxWidth,
                details.localPosition.dy * 340 / constraints.maxHeight,
              );
              for (final entry in svgBodyMapMuscles[widget.side]!.entries) {
                final path =
                    widget.pathOverride?.call(
                      entry.key,
                      document.paths[entry.key]!,
                    ) ??
                    document.paths[entry.key]!;
                if (path.contains(point)) {
                  if (widget.editMode) {
                    widget.onRegionSelected?.call(entry.key);
                  } else {
                    widget.onSelected?.call(entry.value);
                  }
                  return;
                }
              }
            },
            child: CustomPaint(
              painter: _SvgBodyMapPainter(
                document,
                widget.side,
                widget.recoveryByMuscle,
                widget.previewStatuses,
                widget.supportMuscles,
                widget.selectedMuscle,
                editMode: widget.editMode,
                selectedRegionId: widget.selectedRegionId,
                pathOverride: widget.pathOverride,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _SvgBodyMapPainter extends CustomPainter {
  const _SvgBodyMapPainter(
    this.document,
    this.side,
    this.recovery,
    this.previewStatuses,
    this.support,
    this.selected, {
    this.editMode = false,
    this.selectedRegionId,
    this.pathOverride,
  });
  final SvgBodyMapDocument document;
  final SvgBodyMapSide side;
  final Map<MuscleGroup, TrainingRecoveryEvidence> recovery;
  final Map<MuscleGroup, RecoveryStatus> previewStatuses;
  final Set<MuscleGroup> support;
  final MuscleGroup? selected;
  final bool editMode;
  final String? selectedRegionId;
  final SvgBodyMapPathOverride? pathOverride;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200, size.height / 340);
    canvas.drawPath(
      document.paths['${side.name}-body']!,
      Paint()..color = AppColors.secondary.withValues(alpha: .22),
    );
    for (final entry in svgBodyMapMuscles[side]!.entries) {
      final muscle = entry.value;
      final path =
          pathOverride?.call(entry.key, document.paths[entry.key]!) ??
          document.paths[entry.key]!;
      final evidence = recovery[muscle];
      final status = previewStatuses[muscle] ?? evidence?.estimate.status;
      final color = status == null ? AppColors.secondary : _color(status);
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: status == null ? .36 : .78),
      );
      if (support.contains(muscle)) {
        canvas.drawPath(
          path,
          Paint()
            ..color = AppColors.information
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.75,
        );
      }
      if (selected == muscle) {
        canvas.drawPath(
          path,
          Paint()
            ..color = AppColors.textPrimary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
      }
      if (editMode && selectedRegionId == entry.key) {
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.deepPurpleAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SvgBodyMapPainter old) =>
      old.document != document ||
      old.side != side ||
      old.recovery != recovery ||
      old.previewStatuses != previewStatuses ||
      old.support != support ||
      old.selected != selected ||
      old.editMode != editMode ||
      old.selectedRegionId != selectedRegionId ||
      old.pathOverride != pathOverride;
}

Color _color(RecoveryStatus status) => switch (status) {
  RecoveryStatus.loaded => AppColors.danger,
  RecoveryStatus.recovering => AppColors.warning,
  RecoveryStatus.nearReady => AppColors.information,
  RecoveryStatus.estimatedReady => AppColors.success,
  RecoveryStatus.noData => AppColors.secondary,
};

class _SvgPathParser {
  _SvgPathParser(this.source)
    : tokens = RegExp(
        r'[MLCZmlcz]|-?(?:\d+\.?\d*|\.\d+)',
      ).allMatches(source).map((m) => m.group(0)!).toList();
  final String source;
  final List<String> tokens;
  int index = 0;
  double x = 0, y = 0;
  double number() => double.parse(tokens[index++]);
  Path parse() {
    final path = Path();
    while (index < tokens.length) {
      final command = tokens[index++].toUpperCase();
      switch (command) {
        case 'M':
          x = number();
          y = number();
          path.moveTo(x, y);
        case 'L':
          x = number();
          y = number();
          path.lineTo(x, y);
        case 'C':
          final a = Offset(number(), number()), b = Offset(number(), number());
          x = number();
          y = number();
          path.cubicTo(a.dx, a.dy, b.dx, b.dy, x, y);
        case 'Z':
          path.close();
        default:
          throw FormatException('Unsupported SVG command $command in $source');
      }
    }
    return path;
  }
}
