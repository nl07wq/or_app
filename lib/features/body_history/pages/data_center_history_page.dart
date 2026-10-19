import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/global_touch_ripple.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../services/history_visual_preference.dart';

class DataCenterHistoryPage extends StatefulWidget {
  const DataCenterHistoryPage({
    super.key,
    this.visualPreference,
    this.animateAmbient = true,
  });

  final HistoryVisualPreference? visualPreference;
  final bool animateAmbient;

  @override
  State<DataCenterHistoryPage> createState() => _DataCenterHistoryPageState();
}

class _DataCenterHistoryPageState extends State<DataCenterHistoryPage>
    with SingleTickerProviderStateMixin {
  late final HistoryVisualPreference _visualPreference;
  late final AnimationController _ambientController;
  HistoryVisualSelection _selection = const HistoryVisualSelection.defaults();

  @override
  void initState() {
    super.initState();
    _visualPreference = widget.visualPreference ?? HistoryVisualPreference();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 36),
    );
    if (widget.animateAmbient) _ambientController.repeat();
    _restoreSelection();
  }

  Future<void> _restoreSelection() async {
    final restored = await _visualPreference.load();
    if (mounted) setState(() => _selection = restored);
  }

  void _selectTitle(HistoryTitleVariant title) {
    _updateSelection(_selection.copyWith(title: title));
  }

  void _selectAmbient(HistoryAmbientVariant ambient) {
    _updateSelection(_selection.copyWith(ambient: ambient));
  }

  void _updateSelection(HistoryVisualSelection next) {
    if (next == _selection) return;
    setState(() => _selection = next);
    _visualPreference.save(next);
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ambientController,
          builder: (context, _) => CustomPaint(
            key: ValueKey('history-ambient-${_selection.ambient.name}'),
            painter: _HistoryAmbientPainter(
              variant: _selection.ambient,
              phase: _ambientController.value,
            ),
          ),
        ),
      ),
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: const ActionableBackButton(),
          title: _HistoryAppBarTitle(variant: _selection.title),
        ),
        body: _buildContent(context),
      ),
    ],
  );

  Widget _buildContent(BuildContext context) => ListView(
    padding: AppSpacing.cardPadding,
    children: [
      const SectionHeader(icon: Icons.history, title: 'HISTORY'),
      AppSpacing.gapSM,
      _HistoryVisualSelector(
        selection: _selection,
        onTitleSelected: _selectTitle,
        onAmbientSelected: _selectAmbient,
      ),
      AppSpacing.gapMD,
      _HistoryLinkCard(
        title: 'BODY HISTORY',
        description: '保存済みの正式データから、体重と体脂肪率の履歴を表示します。',
        buttonLabel: 'OPEN BODY HISTORY',
        icon: Icons.monitor_weight_outlined,
        onPressed: () => Navigator.pushNamed(context, AppRoutes.bodyHistory),
      ),
      AppSpacing.gapMD,
      _HistoryLinkCard(
        title: 'SLEEP HISTORY',
        description: '保存済みの正式データから、睡眠時間とスコアの履歴を確認します。',
        buttonLabel: 'OPEN SLEEP HISTORY',
        icon: Icons.bedtime_outlined,
        onPressed: () => Navigator.pushNamed(context, AppRoutes.sleepHistory),
      ),
      AppSpacing.gapMD,
      _HistoryLinkCard(
        title: 'NUTRITION HISTORY',
        description: '保存済みの正式データから、摂取・推定消費・カロリー収支の履歴を表示します。',
        buttonLabel: 'OPEN NUTRITION HISTORY',
        icon: Icons.restaurant_outlined,
        onPressed: () =>
            Navigator.pushNamed(context, AppRoutes.nutritionHistory),
      ),
      AppSpacing.gapMD,
      _HistoryLinkCard(
        title: 'TRAINING HISTORY',
        description: '保存済みの正式データから、負荷・回数・セット数・頻度の推移を表示します。',
        buttonLabel: 'OPEN TRAINING HISTORY',
        icon: Icons.fitness_center_outlined,
        onPressed: () =>
            Navigator.pushNamed(context, AppRoutes.trainingAnalyticsHistory),
      ),
      AppSpacing.gapMD,
      _HistoryLinkCard(
        title: 'ACTIVITY HISTORY',
        description: '保存済みの正式データから、歩数の計測状況と日次推移を確認します。',
        buttonLabel: 'OPEN ACTIVITY HISTORY',
        icon: Icons.directions_walk_outlined,
        onPressed: () =>
            Navigator.pushNamed(context, AppRoutes.activityHistory),
      ),
      AppSpacing.gapMD,
      _HistoryLinkCard(
        title: 'DIGESTIVE HISTORY',
        description: '保存済みの正式データから、排便の記録状況と日次推移を確認します。',
        buttonLabel: 'OPEN DIGESTIVE HISTORY',
        icon: Icons.monitor_heart_outlined,
        onPressed: () =>
            Navigator.pushNamed(context, AppRoutes.digestiveHistory),
      ),
    ],
  );
}

class _HistoryLinkCard extends StatelessWidget {
  const _HistoryLinkCard({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        AppSpacing.gapSM,
        Text(description),
        AppSpacing.gapMD,
        OperationButton(
          role: OperationActionRole.primary,
          text: buttonLabel,
          icon: icon,
          onPressed: onPressed,
        ),
      ],
    ),
  );
}

class _HistoryVisualSelector extends StatelessWidget {
  const _HistoryVisualSelector({
    required this.selection,
    required this.onTitleSelected,
    required this.onAmbientSelected,
  });

  final HistoryVisualSelection selection;
  final ValueChanged<HistoryTitleVariant> onTitleSelected;
  final ValueChanged<HistoryAmbientVariant> onAmbientSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'HISTORY visual comparison controls',
    child: Container(
      key: const ValueKey('history-visual-selector'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xff0a1720).withValues(alpha: .62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xff4adcf5).withValues(alpha: .3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChoiceRow<HistoryTitleVariant>(
            label: 'TITLE',
            values: HistoryTitleVariant.values,
            selected: selection.title,
            labels: const ['A DISPLAY', 'B PLATE', 'C MODULE'],
            onSelected: onTitleSelected,
          ),
          const SizedBox(height: 6),
          _ChoiceRow<HistoryAmbientVariant>(
            label: 'AMBIENT',
            values: HistoryAmbientVariant.values,
            selected: selection.ambient,
            labels: const ['A CHRONO', 'B VAULT', 'C STREAM'],
            onSelected: onAmbientSelected,
          ),
        ],
      ),
    ),
  );
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.labels,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T selected;
  final List<String> labels;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 63,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xff89b9c7),
            fontFamily: 'ShareTechMono',
            fontSize: 11,
            letterSpacing: .8,
          ),
        ),
      ),
      Expanded(
        child: Wrap(
          spacing: 5,
          runSpacing: 4,
          children: List.generate(values.length, (index) {
            final value = values[index];
            final isSelected = value == selected;
            return Semantics(
              button: true,
              selected: isSelected,
              label: '$label ${labels[index]}',
              child: ChoiceChip(
                label: Text(labels[index]),
                selected: isSelected,
                onSelected: (_) => onSelected(value),
                visualDensity: VisualDensity.compact,
                labelStyle: TextStyle(
                  color: isSelected
                      ? const Color(0xffe2f9ff)
                      : const Color(0xff9ab3bd),
                  fontFamily: 'ShareTechMono',
                  fontSize: 10,
                ),
                selectedColor: const Color(0xff24566a).withValues(alpha: .82),
                backgroundColor: const Color(0xff091015).withValues(alpha: .58),
                side: BorderSide(
                  color: const Color(
                    0xff62cfe4,
                  ).withValues(alpha: isSelected ? .65 : .22),
                ),
              ),
            );
          }),
        ),
      ),
    ],
  );
}

class _HistoryAppBarTitle extends StatelessWidget {
  const _HistoryAppBarTitle({required this.variant});

  final HistoryTitleVariant variant;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 192,
    height: 42,
    child: CustomPaint(
      key: ValueKey('history-title-${variant.name}'),
      painter: _HistoryTitlePainter(variant),
      child: Align(
        alignment: variant == HistoryTitleVariant.memoryModule
            ? const Alignment(.17, 0)
            : Alignment.center,
        child: Text(
          'HISTORY',
          style: TextStyle(
            color: variant == HistoryTitleVariant.archivePlate
                ? const Color(0xffdcebf2)
                : const Color(0xffd8faff),
            fontFamily: 'ShareTechMono',
            fontSize: variant == HistoryTitleVariant.memoryModule ? 17 : 19,
            fontWeight: FontWeight.w400,
            letterSpacing: variant == HistoryTitleVariant.memoryModule
                ? 1.0
                : variant == HistoryTitleVariant.archivePlate
                ? 1.45
                : 2.1,
            shadows: switch (variant) {
              HistoryTitleVariant.archiveDisplay => const [
                Shadow(color: Color(0xff3edff5), blurRadius: 7),
              ],
              HistoryTitleVariant.archivePlate => const [
                Shadow(color: Color(0xff03070a), offset: Offset(1, 1)),
                Shadow(color: Color(0xffb6d8e2), offset: Offset(0, -0.5)),
              ],
              HistoryTitleVariant.memoryModule => const [
                Shadow(color: Color(0xff37dff7), blurRadius: 4),
              ],
            },
          ),
        ),
      ),
    ),
  );
}

class _HistoryTitlePainter extends CustomPainter {
  const _HistoryTitlePainter(this.variant);

  final HistoryTitleVariant variant;

  @override
  void paint(Canvas canvas, Size size) {
    switch (variant) {
      case HistoryTitleVariant.archiveDisplay:
        _paintArchiveDisplay(canvas, size);
      case HistoryTitleVariant.archivePlate:
        _paintArchivePlate(canvas, size);
      case HistoryTitleVariant.memoryModule:
        _paintMemoryModule(canvas, size);
    }
  }

  void _paintArchiveDisplay(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 4, size.width - 4, size.height - 8),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff234450), Color(0xff07151b), Color(0xff183943)],
        ).createShader(outer.outerRect),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xff5be7f5).withValues(alpha: .72),
    );
    final bezel = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
      const Radius.circular(3),
    );
    canvas.drawRRect(bezel, Paint()..color = const Color(0xff02090d));
    canvas.drawRRect(
      bezel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xff366d79),
    );
    final scan = Paint()
      ..color = const Color(0xff9cf8ff).withValues(alpha: .07);
    for (var y = bezel.top + 3; y < bezel.bottom; y += 3.2) {
      canvas.drawLine(
        Offset(bezel.left + 3, y),
        Offset(bezel.right - 3, y),
        scan,
      );
    }
    final rail = Paint()
      ..strokeWidth = 1.2
      ..color = const Color(0xff78eaf7).withValues(alpha: .45);
    canvas.drawLine(Offset(5, 11), Offset(5, size.height - 11), rail);
    canvas.drawLine(
      Offset(size.width - 5, 11),
      Offset(size.width - 5, size.height - 11),
      rail,
    );
  }

  void _paintArchivePlate(Canvas canvas, Size size) {
    final shadowPath = _beveledPlatePath(size, yOffset: 3);
    canvas.drawPath(shadowPath, Paint()..color = const Color(0xff05090b));
    final platePath = _beveledPlatePath(size);
    final bounds = Rect.fromLTWH(5, 6, size.width - 10, size.height - 12);
    canvas.drawPath(
      platePath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff7894a1), Color(0xff283d47), Color(0xff0c151b)],
          stops: [.0, .42, 1],
        ).createShader(bounds),
    );
    canvas.drawPath(
      platePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15
        ..color = const Color(0xffc0d9e1).withValues(alpha: .72),
    );
    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 12, size.width - 24, size.height - 24),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = const Color(0xffd0e7ed).withValues(alpha: .36),
    );
    for (final x in [14.0, size.width - 14]) {
      for (final y in [13.0, size.height - 13]) {
        canvas.drawCircle(
          Offset(x, y),
          2.2,
          Paint()..color = const Color(0xff111d23),
        );
        canvas.drawCircle(
          Offset(x - .45, y - .45),
          .85,
          Paint()..color = const Color(0xffd3e5e9).withValues(alpha: .72),
        );
      }
    }
  }

  Path _beveledPlatePath(Size size, {double yOffset = 0}) => Path()
    ..moveTo(10, 6 + yOffset)
    ..lineTo(size.width - 10, 6 + yOffset)
    ..lineTo(size.width - 5, 11 + yOffset)
    ..lineTo(size.width - 5, size.height - 11 + yOffset)
    ..lineTo(size.width - 10, size.height - 6 + yOffset)
    ..lineTo(10, size.height - 6 + yOffset)
    ..lineTo(5, size.height - 11 + yOffset)
    ..lineTo(5, 11 + yOffset)
    ..close();

  void _paintMemoryModule(Canvas canvas, Size size) {
    final housing = Path()
      ..moveTo(8, 7)
      ..lineTo(size.width - 37, 7)
      ..lineTo(size.width - 30, 12)
      ..lineTo(size.width - 17, 12)
      ..lineTo(size.width - 17, size.height - 11)
      ..lineTo(size.width - 30, size.height - 11)
      ..lineTo(size.width - 37, size.height - 6)
      ..lineTo(8, size.height - 6)
      ..lineTo(4, size.height - 10)
      ..lineTo(4, 12)
      ..close();
    canvas.drawPath(
      housing,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff1b3c4b), Color(0xff07121a), Color(0xff0d2632)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      housing,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xff47cbe4).withValues(alpha: .7),
    );
    final trace = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = const Color(0xff56e1f4).withValues(alpha: .5);
    for (final y in [13.0, 18.0, size.height - 13, size.height - 18]) {
      canvas.drawLine(Offset(14, y), Offset(32, y), trace);
      canvas.drawLine(Offset(32, y), Offset(38, size.height / 2), trace);
    }
    final contact = Paint()
      ..color = const Color(0xff9dc8d2).withValues(alpha: .78);
    for (var index = 0; index < 5; index++) {
      final top = 11 + index * 4.4;
      canvas.drawRect(Rect.fromLTWH(size.width - 15, top, 7, 2.4), contact);
    }
    final led = Paint()..color = const Color(0xff51ebf7);
    canvas.drawCircle(Offset(13, size.height / 2), 1.5, led);
    canvas.drawCircle(
      Offset(19, size.height / 2),
      1.5,
      led..color = const Color(0xff32788b),
    );
  }

  @override
  bool shouldRepaint(covariant _HistoryTitlePainter oldDelegate) =>
      oldDelegate.variant != variant;
}

class _HistoryAmbientPainter extends CustomPainter {
  const _HistoryAmbientPainter({required this.variant, required this.phase});

  final HistoryAmbientVariant variant;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff071015),
    );
    switch (variant) {
      case HistoryAmbientVariant.chronoArchive:
        _paintChronoArchive(canvas, size);
      case HistoryAmbientVariant.dataVault:
        _paintDataVault(canvas, size);
      case HistoryAmbientVariant.memoryStream:
        _paintMemoryStream(canvas, size);
    }
  }

  void _paintChronoArchive(Canvas canvas, Size size) {
    final center = Offset(size.width * .54, size.height * .43);
    final rotation = phase * math.pi * 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xff4bd9ef).withValues(alpha: .14);
    for (var index = 0; index < 5; index++) {
      final radius = 46.0 + index * 43;
      canvas.drawCircle(center, radius, ring);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2 + rotation * (index.isEven ? 1 : -.55),
        .62 + index * .08,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xff71e8f8).withValues(alpha: .26),
      );
    }
    final tick = Paint()
      ..strokeWidth = .9
      ..color = const Color(0xff8beefa).withValues(alpha: .24);
    for (var index = 0; index < 60; index++) {
      final angle = index / 60 * math.pi * 2 - math.pi / 2;
      final outer = 168.0;
      final inner = outer - (index % 5 == 0 ? 10 : 5);
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * inner,
        center + direction * outer,
        tick,
      );
    }
    _drawPointer(
      canvas,
      center,
      rotation * 1.0,
      130,
      const Color(0xff7cf0ff),
      2.2,
    );
    _drawPointer(
      canvas,
      center,
      -rotation * .37 + .8,
      104,
      const Color(0xff7ea7e8),
      1.6,
    );
    _drawPointer(
      canvas,
      center,
      rotation * 1.8 + 2.3,
      72,
      const Color(0xffe184e1),
      1.1,
    );
    canvas.drawCircle(center, 6, Paint()..color = const Color(0xff08171e));
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xff78eafa).withValues(alpha: .65),
    );
    _drawPoints(canvas, size, const Color(0xff61e5f6), 13, rotation);
  }

  void _paintDataVault(Canvas canvas, Size size) {
    final vanishing = Offset(size.width * .53, size.height * .19);
    final far = Offset(size.width * .5, size.height * .52);
    final rail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xff66cddd).withValues(alpha: .17);
    for (var index = 0; index <= 8; index++) {
      final floorX = size.width * (index / 8);
      canvas.drawLine(vanishing, Offset(floorX, size.height), rail);
    }
    for (var row = 0; row < 7; row++) {
      final t = row / 7;
      final y = far.dy + (size.height - far.dy) * t * t;
      final width = size.width * (.18 + .82 * t);
      final left = size.width / 2 - width / 2;
      final height = 18 + t * 28;
      final rack = Path()
        ..moveTo(left, y)
        ..lineTo(left + width, y)
        ..lineTo(left + width - 8 * t, y + height)
        ..lineTo(left + 8 * t, y + height)
        ..close();
      canvas.drawPath(
        rack,
        Paint()
          ..color = const Color(0xff0d2933).withValues(alpha: .36 + t * .14),
      );
      canvas.drawPath(rack, rail);
      final slotCount = 3 + (t * 3).round();
      for (var slot = 0; slot < slotCount; slot++) {
        final fraction = slot / slotCount;
        final slotLeft = left + width * fraction + 5;
        final slotWidth = width / slotCount - 10;
        final slotRect = Rect.fromLTWH(slotLeft, y + 4, slotWidth, height - 8);
        canvas.drawRect(
          slotRect,
          Paint()..color = const Color(0xff02090e).withValues(alpha: .54),
        );
        final access = (phase * 2.7 + row * .19 + slot * .13) % 1;
        if (access > .78) {
          canvas.drawRect(
            Rect.fromLTWH(
              slotLeft + 2,
              y + height / 2 - 1,
              math.max(2, slotWidth - 4),
              2,
            ),
            Paint()..color = const Color(0xff5ce7f5).withValues(alpha: .65),
          );
        }
      }
    }
    final sideWall = Paint()
      ..color = const Color(0xff12333e).withValues(alpha: .18);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(vanishing.dx, vanishing.dy)
        ..lineTo(0, size.height)
        ..close(),
      sideWall,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width, 0)
        ..lineTo(vanishing.dx, vanishing.dy)
        ..lineTo(size.width, size.height)
        ..close(),
      sideWall,
    );
  }

  void _paintMemoryStream(Canvas canvas, Size size) {
    final paths = <Path>[
      Path()
        ..moveTo(-10, size.height * .2)
        ..cubicTo(
          size.width * .16,
          size.height * .16,
          size.width * .22,
          size.height * .53,
          size.width * .48,
          size.height * .42,
        )
        ..cubicTo(
          size.width * .7,
          size.height * .32,
          size.width * .77,
          size.height * .15,
          size.width + 10,
          size.height * .25,
        ),
      Path()
        ..moveTo(-10, size.height * .68)
        ..cubicTo(
          size.width * .22,
          size.height * .77,
          size.width * .3,
          size.height * .29,
          size.width * .54,
          size.height * .46,
        )
        ..cubicTo(
          size.width * .75,
          size.height * .61,
          size.width * .78,
          size.height * .78,
          size.width + 10,
          size.height * .7,
        ),
      Path()
        ..moveTo(size.width * .05, size.height + 8)
        ..cubicTo(
          size.width * .19,
          size.height * .72,
          size.width * .37,
          size.height * .62,
          size.width * .53,
          size.height * .47,
        )
        ..cubicTo(
          size.width * .69,
          size.height * .31,
          size.width * .91,
          size.height * .49,
          size.width + 10,
          size.height * .45,
        ),
      Path()
        ..moveTo(-8, size.height * .43)
        ..cubicTo(
          size.width * .18,
          size.height * .38,
          size.width * .3,
          size.height * .44,
          size.width * .48,
          size.height * .42,
        ),
    ];
    final colors = [
      const Color(0xff54dff3),
      const Color(0xff718fe5),
      const Color(0xff9a75c7),
      const Color(0xff3abfd9),
    ];
    for (var index = 0; index < paths.length; index++) {
      final trace = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = index == 3 ? 1 : 1.7
        ..strokeCap = StrokeCap.round
        ..color = colors[index].withValues(alpha: .23);
      canvas.drawPath(paths[index], trace);
      final metrics = paths[index].computeMetrics().toList(growable: false);
      if (metrics.isEmpty) continue;
      final metric = metrics.single;
      for (var particle = 0; particle < 3; particle++) {
        final progress =
            (phase * (0.38 + index * .11) + particle / 3 + index * .17) % 1;
        final tangent = metric.getTangentForOffset(metric.length * progress);
        if (tangent == null) continue;
        canvas.drawCircle(
          tangent.position,
          2.0 - index * .15,
          Paint()..color = colors[index].withValues(alpha: .68),
        );
      }
    }
    final node = Paint()
      ..color = const Color(0xff80ebf8).withValues(alpha: .42);
    for (final point in [
      Offset(size.width * .48, size.height * .42),
      Offset(size.width * .54, size.height * .46),
    ]) {
      canvas.drawCircle(point, 5 + math.sin(phase * math.pi * 2) * 1.5, node);
      canvas.drawCircle(point, 1.7, Paint()..color = const Color(0xffb5fbff));
    }
  }

  void _drawPointer(
    Canvas canvas,
    Offset center,
    double angle,
    double length,
    Color color,
    double width,
  ) {
    final end = center + Offset(math.cos(angle), math.sin(angle)) * length;
    canvas.drawLine(
      center,
      end,
      Paint()
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: .62),
    );
  }

  void _drawPoints(
    Canvas canvas,
    Size size,
    Color color,
    int count,
    double rotation,
  ) {
    final paint = Paint();
    for (var index = 0; index < count; index++) {
      final normalized = index / count;
      final x = (math.sin(index * 2.41 + rotation) * .42 + .5) * size.width;
      final y =
          (math.cos(index * 1.67 + rotation * .7) * .42 + .5) * size.height;
      paint.color = color.withValues(alpha: .16 + normalized * .17);
      canvas.drawCircle(Offset(x, y), 1.2 + normalized * 1.8, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryAmbientPainter oldDelegate) =>
      oldDelegate.variant != variant || oldDelegate.phase != phase;
}
