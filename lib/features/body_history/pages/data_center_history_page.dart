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
      outer.shift(const Offset(0, 1.4)),
      Paint()..color = const Color(0xff010507).withValues(alpha: .72),
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff345b66), Color(0xff09171e), Color(0xff183540)],
          stops: [0, .48, 1],
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
    canvas.drawRRect(
      bezel,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff07141a), Color(0xff010608)],
        ).createShader(bezel.outerRect),
    );
    canvas.drawRRect(
      bezel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xff366d79),
    );
    final scan = Paint()..color = const Color(0xff9cf8ff).withValues(alpha: .045);
    for (var y = bezel.top + 3; y < bezel.bottom; y += 4) {
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
    final indicator = Paint()..color = const Color(0xff74eff9).withValues(alpha: .6);
    canvas.drawCircle(Offset(12, size.height / 2), 1.3, indicator);
    canvas.drawCircle(Offset(size.width - 12, size.height / 2), 1.3, indicator);
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
    final topBevel = Path()
      ..moveTo(10, 7)
      ..lineTo(size.width - 10, 7)
      ..lineTo(size.width - 6, 11)
      ..lineTo(9, 11)
      ..close();
    canvas.drawPath(
      topBevel,
      Paint()..color = const Color(0xffd4ecf0).withValues(alpha: .18),
    );
    final bottomBevel = Path()
      ..moveTo(9, size.height - 10)
      ..lineTo(size.width - 6, size.height - 10)
      ..lineTo(size.width - 10, size.height - 6)
      ..lineTo(10, size.height - 6)
      ..close();
    canvas.drawPath(
      bottomBevel,
      Paint()..color = const Color(0xff020609).withValues(alpha: .46),
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
      ..moveTo(10, 5)
      ..lineTo(size.width - 46, 5)
      ..lineTo(size.width - 40, 10)
      ..lineTo(size.width - 25, 10)
      ..lineTo(size.width - 25, 14)
      ..lineTo(size.width - 13, 14)
      ..lineTo(size.width - 13, size.height - 14)
      ..lineTo(size.width - 25, size.height - 14)
      ..lineTo(size.width - 32, size.height - 8)
      ..lineTo(10, size.height - 8)
      ..lineTo(4, size.height - 14)
      ..lineTo(4, 11)
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
    final innerModule = RRect.fromRectAndRadius(
      Rect.fromLTWH(12, 11, size.width - 52, size.height - 22),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      innerModule,
      Paint()..color = const Color(0xff02090e).withValues(alpha: .44),
    );
    canvas.drawRRect(
      innerModule,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = const Color(0xff76ddec).withValues(alpha: .3),
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
      canvas.drawLine(Offset(10, y), Offset(28, y), trace);
      canvas.drawLine(Offset(28, y), Offset(36, size.height / 2), trace);
    }
    final contact = Paint()
      ..color = const Color(0xff9dc8d2).withValues(alpha: .78);
    for (var index = 0; index < 5; index++) {
      final top = 10 + index * 4.6;
      canvas.drawRect(Rect.fromLTWH(size.width - 18, top, 9, 2.5), contact);
    }
    final led = Paint()..color = const Color(0xff51ebf7);
    canvas.drawCircle(Offset(11, size.height / 2), 1.5, led);
    canvas.drawCircle(
      Offset(17, size.height / 2),
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
    final timelineY = size.height * .31;
    final left = size.width * .08;
    final right = size.width * .92;
    final cycle = phase * math.pi * 2;
    final rail = Paint()
      ..strokeWidth = 1.3
      ..color = const Color(0xff53dced).withValues(alpha: .24);
    canvas.drawLine(Offset(left, timelineY), Offset(right, timelineY), rail);
    canvas.drawLine(
      Offset(left, timelineY + 4),
      Offset(right, timelineY + 4),
      Paint()
        ..strokeWidth = .45
        ..color = const Color(0xff8df2ff).withValues(alpha: .2),
    );
    final nodes = <Offset>[
      Offset(size.width * .16, timelineY),
      Offset(size.width * .39, timelineY + size.height * .055),
      Offset(size.width * .63, timelineY - size.height * .036),
      Offset(size.width * .85, timelineY + size.height * .035),
    ];
    for (var index = 0; index < nodes.length; index++) {
      final center = nodes[index];
      final radius = 21.0 + (index % 2) * 5;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xff5ddfec).withValues(alpha: .22 + index * .025);
      canvas.drawCircle(center, radius, ring);
      canvas.drawCircle(center, radius * .68, ring..color = const Color(0xff74e9fa).withValues(alpha: .13));
      for (var tick = 0; tick < 16; tick++) {
        final angle = tick / 16 * math.pi * 2 + index * .31;
        final direction = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(center + direction * (radius + 2), center + direction * (radius + (tick % 4 == 0 ? 6 : 4)), ring);
      }
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * .82),
        cycle * (index.isEven ? .28 : -.19) + index,
        .9 + index * .12,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.9
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xff8af3ff).withValues(alpha: .44),
      );
      canvas.drawCircle(center, 3.2, Paint()..color = const Color(0xff07171d));
      canvas.drawCircle(center, 1.2, Paint()..color = const Color(0xff92f4ff).withValues(alpha: .8));
      final annotation = Paint()..color = const Color(0xff77dbe8).withValues(alpha: .22);
      canvas.drawLine(Offset(center.dx - 9, center.dy + radius + 10), Offset(center.dx + 9, center.dy + radius + 10), annotation);
      canvas.drawLine(Offset(center.dx - 5, center.dy + radius + 13), Offset(center.dx + 5, center.dy + radius + 13), annotation);
    }
    for (var point = 0; point < 5; point++) {
      final progress = (phase + point / 5) % 1;
      final x = left + (right - left) * progress;
      canvas.drawCircle(
        Offset(x, timelineY + math.sin(progress * math.pi * 4) * 2),
        point == 0 ? 2.5 : 1.4,
        Paint()..color = const Color(0xffa0f5ff).withValues(alpha: .45),
      );
    }
    _drawPoints(canvas, size, const Color(0xff61e5f6), 10, cycle);
  }

  void _paintDataVault(Canvas canvas, Size size) {
    final vanishing = Offset(size.width * .5, size.height * .31);
    final leftWall = Path()
      ..moveTo(0, 0)
      ..lineTo(vanishing.dx, vanishing.dy)
      ..lineTo(0, size.height)
      ..close();
    final rightWall = Path()
      ..moveTo(size.width, 0)
      ..lineTo(vanishing.dx, vanishing.dy)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(leftWall, Paint()..color = const Color(0xff0c2532).withValues(alpha: .32));
    canvas.drawPath(rightWall, Paint()..color = const Color(0xff102a39).withValues(alpha: .32));
    final rail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = const Color(0xff69d9ea).withValues(alpha: .2);
    final floorCenter = Offset(size.width * .5, size.height * 1.04);
    for (var index = 0; index < 8; index++) {
      final target = Offset(size.width * (index / 7), size.height);
      canvas.drawLine(vanishing, target, rail);
    }
    canvas.drawLine(vanishing, floorCenter, rail..color = const Color(0xff8beefa).withValues(alpha: .34));
    for (var plane = 0; plane < 7; plane++) {
      final depth = plane / 6;
      final curve = depth * depth;
      final y = vanishing.dy + (size.height - vanishing.dy) * curve;
      final halfWidth = size.width * (.055 + curve * .54);
      final left = size.width / 2 - halfWidth;
      final right = size.width / 2 + halfWidth;
      canvas.drawLine(Offset(left, y), Offset(right, y), rail..color = const Color(0xff60d8e9).withValues(alpha: .09 + curve * .12));
      if (plane < 6) {
        canvas.drawLine(Offset(left, y), Offset(left, y + 13 + curve * 24), rail);
        canvas.drawLine(Offset(right, y), Offset(right, y + 13 + curve * 24), rail);
      }
    }
    for (var index = 0; index < 14; index++) {
      final side = index.isEven ? -1.0 : 1.0;
      final depth = ((index * .113 + .06) % 1);
      final curve = depth * depth;
      final baseY = vanishing.dy + (size.height - vanishing.dy) * curve;
      final edgeX = size.width / 2 + side * size.width * (.07 + curve * .52);
      final height = 14 + curve * 135;
      final width = 1 + curve * 2.4;
      final pillarColor = side < 0
          ? const Color(0xff45c9e1)
          : const Color(0xff7897ed);
      final outerPillar = Path()
        ..moveTo(edgeX - side * (7 + curve * 10), baseY)
        ..lineTo(edgeX + side * (7 + curve * 10), baseY)
        ..lineTo(edgeX + side * (2 + curve * 4), baseY - height)
        ..lineTo(edgeX - side * (2 + curve * 4), baseY - height)
        ..close();
      canvas.drawPath(
        outerPillar,
        Paint()..color = pillarColor.withValues(alpha: .025 + curve * .065),
      );
      final pillar = Paint()
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = pillarColor.withValues(alpha: .16 + curve * .28);
      canvas.drawLine(
        Offset(edgeX, baseY),
        Offset(edgeX + side * curve * 9, baseY - height),
        pillar,
      );
      canvas.drawLine(
        Offset(edgeX + side * (6 + curve * 6), baseY),
        Offset(edgeX + side * (2 + curve * 4), baseY - height),
        Paint()
          ..strokeWidth = .7
          ..color = pillarColor.withValues(alpha: .1 + curve * .14),
      );
    }
    for (var trail = 0; trail < 4; trail++) {
      final progress = (phase * .62 + trail / 4) % 1;
      final y = vanishing.dy + (size.height - vanishing.dy) * progress * progress;
      final width = size.width * (.1 + progress * .75);
      canvas.drawLine(
        Offset(size.width / 2 - width / 2, y),
        Offset(size.width / 2 + width / 2, y),
        Paint()
          ..strokeWidth = 1.2
          ..color = const Color(0xff80eff8).withValues(alpha: .12 + (1 - progress) * .24),
      );
    }
    for (var pulse = 0; pulse < 5; pulse++) {
      final progress = (phase * .84 + pulse / 5) % 1;
      final side = pulse.isEven ? -1.0 : 1.0;
      final y = vanishing.dy + (size.height - vanishing.dy) * progress * progress;
      final x = size.width / 2 + side * size.width * (.08 + progress * progress * .45);
      canvas.drawCircle(Offset(x, y), 1.5 + progress, Paint()..color = const Color(0xff9cf7ff).withValues(alpha: .43));
    }
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
