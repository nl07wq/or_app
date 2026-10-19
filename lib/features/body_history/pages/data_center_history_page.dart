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
    final scan = Paint()
      ..color = const Color(0xff9cf8ff).withValues(alpha: .045);
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
    final indicator = Paint()
      ..color = const Color(0xff74eff9).withValues(alpha: .6);
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
      canvas.drawCircle(
        center,
        radius * .68,
        ring..color = const Color(0xff74e9fa).withValues(alpha: .13),
      );
      for (var tick = 0; tick < 16; tick++) {
        final angle = tick / 16 * math.pi * 2 + index * .31;
        final direction = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          center + direction * (radius + 2),
          center + direction * (radius + (tick % 4 == 0 ? 6 : 4)),
          ring,
        );
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
      canvas.drawCircle(
        center,
        1.2,
        Paint()..color = const Color(0xff92f4ff).withValues(alpha: .8),
      );
      final annotation = Paint()
        ..color = const Color(0xff77dbe8).withValues(alpha: .22);
      canvas.drawLine(
        Offset(center.dx - 9, center.dy + radius + 10),
        Offset(center.dx + 9, center.dy + radius + 10),
        annotation,
      );
      canvas.drawLine(
        Offset(center.dx - 5, center.dy + radius + 13),
        Offset(center.dx + 5, center.dy + radius + 13),
        annotation,
      );
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
    // DATA VAULT V1.3: a filled architectural corridor, deliberately not a
    // wireframe. Geometry is normalized to keep its depth hierarchy stable.
    final viewport = Offset.zero & size;
    final w = size.width;
    final h = size.height;
    final aperture = Rect.fromLTRB(w * .4, h * .33, w * .6, h * .66);
    final focal = Offset(w * .5, h * .33);
    final leftWall = Path()
      ..moveTo(0, 0)
      ..lineTo(aperture.left, aperture.top)
      ..lineTo(aperture.left, aperture.bottom)
      ..lineTo(0, h)
      ..close();
    final rightWall = Path()
      ..moveTo(w, 0)
      ..lineTo(aperture.right, aperture.top)
      ..lineTo(aperture.right, aperture.bottom)
      ..lineTo(w, h)
      ..close();
    final ceiling = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(aperture.right, aperture.top)
      ..lineTo(aperture.left, aperture.top)
      ..close();
    final floor = Path()
      ..moveTo(0, h)
      ..lineTo(aperture.left, aperture.bottom)
      ..lineTo(aperture.right, aperture.bottom)
      ..lineTo(w, h)
      ..close();

    canvas.save();
    canvas.clipRect(viewport);
    // 1–2: opaque base and recessed atmospheric depth.
    canvas.drawRect(viewport, Paint()..color = const Color(0xff030a14));
    canvas.drawRect(
      viewport,
      Paint()
        ..shader =
            RadialGradient(
              center: Alignment.center,
              radius: 1,
              colors: [
                const Color(0xff164467).withValues(alpha: .5),
                const Color(0xff092139).withValues(alpha: .55),
                const Color(0xff030a14),
              ],
              stops: const [.0, .48, 1],
            ).createShader(
              Rect.fromCircle(center: Offset(w * .5, h * .39), radius: h * .85),
            ),
    );

    // 3–5: solid room planes around the deliberately dark rear aperture.
    canvas.drawPath(
      ceiling,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xff07192a).withValues(alpha: .8),
            const Color(0xff020811).withValues(alpha: .82),
          ],
        ).createShader(ceiling.getBounds()),
    );
    canvas.drawPath(
      leftWall,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xff071627).withValues(alpha: .84),
            const Color(0xff0e314b).withValues(alpha: .68),
            const Color(0xff020811).withValues(alpha: .8),
          ],
        ).createShader(leftWall.getBounds()),
    );
    canvas.drawPath(
      rightWall,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            const Color(0xff071627).withValues(alpha: .84),
            const Color(0xff0e314b).withValues(alpha: .68),
            const Color(0xff020811).withValues(alpha: .8),
          ],
        ).createShader(rightWall.getBounds()),
    );
    canvas.drawRect(
      aperture,
      Paint()..color = const Color(0xff020b16).withValues(alpha: .85),
    );
    canvas.drawRect(
      aperture,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xff46c7ed).withValues(alpha: .28),
    );
    canvas.drawPath(
      floor,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xff0b2c48).withValues(alpha: .76),
            const Color(0xff020811).withValues(alpha: .94),
          ],
        ).createShader(floor.getBounds()),
    );
    _paintVaultFloorChannels(canvas, size, aperture, floor);

    // 6–8: six depth-projected pillar pairs, back to front.
    const depths = [.10, .24, .39, .55, .73, .92];
    for (var group = 0; group < 3; group++) {
      final start = group * 2;
      for (var index = start; index < start + 2; index++) {
        for (final side in [-1.0, 1.0]) {
          _paintVaultPillar(
            canvas,
            size,
            depth: depths[index],
            index: index,
            side: side,
            clip: side < 0 ? leftWall : rightWall,
          );
        }
      }
    }

    // 9: short, clipped reflections only for middle and near columns.
    canvas.save();
    canvas.clipPath(floor);
    for (var index = 2; index < depths.length; index++) {
      for (final side in [-1.0, 1.0]) {
        _paintVaultReflection(canvas, size, depths[index], side);
      }
    }
    canvas.restore();

    // 10: pulses use a zero-alpha envelope at the cyclic boundary.
    _paintVaultPulses(canvas, size, focal);
    // 11: sparse surface accents, intentionally subordinate to volume.
    final accent = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = const Color(0xff75e5f7).withValues(alpha: .12);
    canvas.drawLine(
      Offset(0, h * .06),
      Offset(aperture.left, aperture.top),
      accent,
    );
    canvas.drawLine(
      Offset(w, h * .06),
      Offset(aperture.right, aperture.top),
      accent,
    );
    canvas.restore();
  }

  void _paintVaultFloorChannels(
    Canvas canvas,
    Size size,
    Rect aperture,
    Path floor,
  ) {
    final w = size.width;
    final h = size.height;
    final channelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const near = [.10, .30, .50, .70, .90];
    const far = [.42, .46, .50, .54, .58];
    for (var index = 0; index < near.length; index++) {
      channelPaint
        ..strokeWidth = .7 + index * .17
        ..color = const Color(0xff40b4df).withValues(alpha: .12 + index * .035);
      canvas.drawLine(
        Offset(w * far[index], aperture.bottom),
        Offset(w * near[index], h),
        channelPaint,
      );
    }
    for (final v in [.72, .79, .88, .98]) {
      final progress = ((v - .66) / .34).clamp(0.0, 1.0);
      final halfWidth = w * (.1 + .4 * progress);
      channelPaint
        ..strokeWidth = .8
        ..color = const Color(
          0xff40b4df,
        ).withValues(alpha: .1 + progress * .08);
      canvas.drawLine(
        Offset(w * .5 - halfWidth, h * v),
        Offset(w * .5 + halfWidth, h * v),
        channelPaint,
      );
    }
  }

  void _paintVaultPillar(
    Canvas canvas,
    Size size, {
    required double depth,
    required int index,
    required double side,
    required Path clip,
  }) {
    final w = size.width;
    final h = size.height;
    final p = depth * depth;
    final centerX = w * (side < 0 ? .4 - .38 * p : .6 + .38 * p);
    final top = h * (.33 - .33 * p);
    final bottom = h * (.66 + .34 * p);
    final bodyWidth = math.min(3 + 14 * p, math.max(3.0, w * .052));
    final lean = side * (1 + 3 * p);
    final body = Path()
      ..moveTo(centerX - bodyWidth / 2 + lean, top)
      ..lineTo(centerX + bodyWidth / 2 + lean, top)
      ..lineTo(centerX + bodyWidth / 2, bottom)
      ..lineTo(centerX - bodyWidth / 2, bottom)
      ..close();
    final bright = .18 + .57 * p;
    final blueBias = index.isOdd;
    final base = blueBias ? const Color(0xff4b9eff) : const Color(0xff29bce4);
    canvas.save();
    canvas.clipPath(clip);
    canvas.drawPath(
      body,
      Paint()..color = base.withValues(alpha: .06 + .06 * p),
    );
    final volume = body.getBounds().inflate(bodyWidth * .9);
    canvas.drawRect(
      volume,
      Paint()
        ..shader = LinearGradient(
          colors: [
            base.withValues(alpha: .0),
            base.withValues(alpha: .12 * bright),
            base.withValues(alpha: .0),
          ],
          stops: const [0, .5, 1],
        ).createShader(volume),
    );
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xff2e9ebf).withValues(alpha: .03 * bright),
            (blueBias ? const Color(0xff62c9ff) : const Color(0xff29bce4))
                .withValues(alpha: .30 * bright),
            const Color(0xff91f4ff).withValues(alpha: .90 * bright),
            (blueBias ? const Color(0xff62c9ff) : const Color(0xff25b9e3))
                .withValues(alpha: .30 * bright),
            const Color(0xff2e9ebf).withValues(alpha: .03 * bright),
          ],
          stops: const [0, .3, .5, .7, 1],
        ).createShader(body.getBounds()),
    );
    final stripWidth = math.max(1, bodyWidth * .2).toDouble();
    final strip = Rect.fromCenter(
      center: Offset(centerX + lean * .45, (top + bottom) / 2),
      width: stripWidth,
      height: bottom - top,
    );
    canvas.drawRect(
      strip,
      Paint()..color = const Color(0xffc7fbff).withValues(alpha: .45 + .35 * p),
    );
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = const Color(0xffb5f7ff).withValues(alpha: .2 * bright);
    canvas.drawPath(body, edge);
    canvas.restore();
  }

  void _paintVaultReflection(
    Canvas canvas,
    Size size,
    double depth,
    double side,
  ) {
    final p = depth * depth;
    final centerX = size.width * (side < 0 ? .4 - .38 * p : .6 + .38 * p);
    final contactY = size.height * (.66 + .34 * p);
    final width = math.min(3 + 14 * p, math.max(3.0, size.width * .052)) * 1.5;
    final length = math.min(size.height * .12, 50 + 40 * p);
    final reflection = Rect.fromCenter(
      center: Offset(centerX, contactY + length / 2),
      width: width,
      height: length,
    );
    canvas.drawRect(
      reflection,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xff75eafa).withValues(alpha: .12),
            const Color(0xff75eafa).withValues(alpha: 0),
          ],
        ).createShader(reflection),
    );
  }

  void _paintVaultPulses(Canvas canvas, Size size, Offset focal) {
    final theta = phase * math.pi * 2;
    for (var index = 0; index < 3; index++) {
      final q = (phase + index / 3) % 1;
      final smooth = q * q * (3 - 2 * q);
      final envelope = math.pow(math.sin(math.pi * q), 2).toDouble();
      final side = index == 1 ? 1.0 : -1.0;
      Offset position;
      if (index == 2) {
        final far = Offset(size.width * .5, size.height * .66);
        final near = Offset(size.width * .9, size.height);
        position = Offset.lerp(far, near, smooth)!;
      } else {
        final p = smooth * smooth;
        final x = size.width * (side < 0 ? .4 - .38 * p : .6 + .38 * p);
        final top = size.height * (.33 - .33 * p);
        final bottom = size.height * (.66 + .34 * p);
        position = Offset(
          x,
          top + (bottom - top) * (.36 + .22 * math.sin(theta + index)),
        );
      }
      canvas.drawCircle(
        position,
        1 + 1.5 * smooth,
        Paint()
          ..color = const Color(0xffa8f8ff).withValues(alpha: .4 * envelope),
      );
    }
    // Keep the specified focal point part of the architectural coordinate
    // contract while retaining a dark aperture.
    canvas.drawCircle(
      focal,
      .65,
      Paint()..color = const Color(0xff8df4ff).withValues(alpha: .12),
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
