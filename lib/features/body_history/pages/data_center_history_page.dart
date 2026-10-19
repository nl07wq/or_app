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
      child: Center(
        child: Text(
          'HISTORY',
          style: TextStyle(
            color: variant == HistoryTitleVariant.archivePlate
                ? const Color(0xffdcebf2)
                : const Color(0xffd8faff),
            fontFamily: 'ShareTechMono',
            fontSize: 19,
            fontWeight: FontWeight.w400,
            letterSpacing: variant == HistoryTitleVariant.memoryModule
                ? 1.3
                : 2.1,
            shadows: variant == HistoryTitleVariant.archiveDisplay
                ? const [Shadow(color: Color(0xff3edff5), blurRadius: 7)]
                : null,
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
    final frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 3, size.width - 2, size.height - 6),
      const Radius.circular(5),
    );
    final fill = Paint()
      ..color = switch (variant) {
        HistoryTitleVariant.archiveDisplay => const Color(
          0xff06141b,
        ).withValues(alpha: .88),
        HistoryTitleVariant.archivePlate => const Color(
          0xff1a252b,
        ).withValues(alpha: .9),
        HistoryTitleVariant.memoryModule => const Color(
          0xff07101a,
        ).withValues(alpha: .92),
      };
    canvas.drawRRect(frame, fill);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = switch (variant) {
        HistoryTitleVariant.archiveDisplay => const Color(
          0xff54ddec,
        ).withValues(alpha: .72),
        HistoryTitleVariant.archivePlate => const Color(
          0xff9ab4c0,
        ).withValues(alpha: .72),
        HistoryTitleVariant.memoryModule => const Color(
          0xff4a94bd,
        ).withValues(alpha: .82),
      };
    canvas.drawRRect(frame, border);
    switch (variant) {
      case HistoryTitleVariant.archiveDisplay:
        final scan = Paint()
          ..color = const Color(0xff7af1ff).withValues(alpha: .10);
        for (var y = 8.0; y < size.height - 4; y += 4) {
          canvas.drawLine(Offset(6, y), Offset(size.width - 6, y), scan);
        }
      case HistoryTitleVariant.archivePlate:
        final line = Paint()
          ..color = const Color(0xffa7cbd8).withValues(alpha: .46)
          ..strokeWidth = .8;
        canvas.drawLine(Offset(9, 10), Offset(size.width - 9, 10), line);
        canvas.drawLine(
          Offset(9, size.height - 10),
          Offset(size.width - 9, size.height - 10),
          line,
        );
      case HistoryTitleVariant.memoryModule:
        final indicator = Paint()
          ..color = const Color(0xff3ee5fc).withValues(alpha: .85);
        for (final x in [10.0, 15.0, size.width - 15, size.width - 10]) {
          canvas.drawCircle(Offset(x, size.height / 2), 1.4, indicator);
        }
        final access = Paint()
          ..color = const Color(0xff5fd4f3).withValues(alpha: .55);
        canvas.drawLine(
          Offset(24, size.height - 8),
          Offset(size.width - 24, size.height - 8),
          access,
        );
    }
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
    final center = Offset(size.width * .54, size.height * .42);
    final rotation = phase * math.pi * 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xff4bd9ef).withValues(alpha: .12);
    for (var index = 1; index <= 5; index++) {
      canvas.drawCircle(
        center,
        42.0 * index + math.sin(rotation + index) * 5,
        ring,
      );
    }
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xff76e9fb).withValues(alpha: .25);
    for (var index = 0; index < 3; index++) {
      final radius = 72.0 + index * 61;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        rotation + index * 1.9,
        .55,
        false,
        arc,
      );
    }
    _drawPoints(canvas, size, const Color(0xff61e5f6), 18, rotation);
  }

  void _paintDataVault(Canvas canvas, Size size) {
    final channel = Paint()
      ..color = const Color(0xff4a7f92).withValues(alpha: .12);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xff63cde3).withValues(alpha: .18);
    for (var index = 0; index < 6; index++) {
      final x =
          size.width * (.08 + index * .17) +
          math.sin(phase * math.pi * 2 + index) * 3;
      final rect = Rect.fromLTWH(x, 0, size.width * .09, size.height);
      canvas.drawRect(rect, channel);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), edge);
    }
    final slot = Paint()
      ..color = const Color(0xff0d2831).withValues(alpha: .34)
      ..style = PaintingStyle.fill;
    final slotEdge = Paint()
      ..color = const Color(0xff77dce8).withValues(alpha: .18)
      ..style = PaintingStyle.stroke;
    for (var y = 40.0; y < size.height; y += 82) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(18, y, size.width - 36, 38),
          const Radius.circular(4),
        ),
        slot,
      );
      canvas.drawLine(Offset(18, y), Offset(size.width - 18, y), slotEdge);
    }
    _drawPoints(canvas, size, const Color(0xff78e5f2), 12, phase * math.pi * 2);
  }

  void _paintMemoryStream(Canvas canvas, Size size) {
    final trace = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 9; index++) {
      final baseY = size.height * (.08 + index * .11);
      final path = Path()..moveTo(0, baseY);
      for (var x = 0.0; x <= size.width; x += 16) {
        final y =
            baseY +
            math.sin(x / 42 + phase * math.pi * 2 + index) *
                (5 + index % 3 * 2);
        path.lineTo(x, y);
      }
      trace.color = Color.lerp(
        const Color(0xff2d8faf),
        const Color(0xff9e7bc5),
        index / 9,
      )!.withValues(alpha: .2);
      canvas.drawPath(path, trace);
    }
    _drawPoints(canvas, size, const Color(0xff83e8fa), 16, phase * math.pi * 2);
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
