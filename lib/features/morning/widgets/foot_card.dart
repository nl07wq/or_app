import 'package:flutter/material.dart';

import 'package:or_app/core/widgets/global_touch_ripple.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dashboard_glass_card.dart';
import '../../../core/widgets/section_header.dart';

class FootCard extends StatefulWidget {
  final TextEditingController controller;
  final bool initiallyExpanded;

  const FootCard({
    super.key,
    required this.controller,
    this.initiallyExpanded = false,
  });

  @override
  State<FootCard> createState() => _FootCardState();
}

class _FootCardState extends State<FootCard> {
  late bool _editing;

  int? get _selectedValue => int.tryParse(widget.controller.text);
  bool get _hasSelectedValue {
    final value = _selectedValue;
    return value != null && value >= 1 && value <= 10;
  }

  @override
  void initState() {
    super.initState();
    _editing = widget.initiallyExpanded || !_hasSelectedValue;
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(FootCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;

    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;

    setState(() {});
  }

  void _selectPainLevel(int value) {
    widget.controller.text = value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return DashboardGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            icon: Icons.accessibility_new,
            title: "FOOT HEALTH",
          ),

          const SizedBox(height: 20),

          if (!_editing)
            Semantics(
              button: true,
              label:
                  'PAIN LEVEL ${_hasSelectedValue ? 'LV.$_selectedValue /10' : '未選択'} 再編集',
              child: InkWell(
                key: const Key('foot-pain-current-value-button'),
                onTap: () => setState(() => _editing = true),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainer.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: .35)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'PAIN LEVEL',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        _hasSelectedValue ? 'LV.$_selectedValue /10' : '未選択',
                        key: const Key('foot-pain-current-value'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: color,
                          fontFamily: 'ShareTechMono',
                        ),
                      ),
                      Icon(Icons.edit_outlined, size: 18, color: color),
                    ],
                  ),
                ),
              ).actionableFeedback(role: ActionableFeedbackRole.cursor),
            )
          else ...[
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'PAIN LEVEL',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    _hasSelectedValue ? 'LV.$_selectedValue /10' : '未選択',
                    key: const Key('foot-pain-current-value'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontFamily: 'ShareTechMono',
                    ),
                  ),
                ],
              ),
            ),

            AppSpacing.gapMD,

            _FootPainScale(
              key: const Key('foot-pain-scale'),
              value: _hasSelectedValue ? _selectedValue : null,
              onChanged: _selectPainLevel,
            ),

            AppSpacing.gapMD,

            Text(
              '0–2 軽度   3–4 監視   5–6 保護検討   7以上 強保護候補',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('foot-pain-done'),
                onPressed: () => setState(() => _editing = false),
                child: const Text('完了'),
              ).actionableFeedback(role: ActionableFeedbackRole.cursor),
            ),
          ],
        ],
      ),
    );
  }
}

/// A presentation-only 1..10 rail.  It deliberately leaves null unmeasured
/// rather than treating the left edge as a hidden zero value.
class _FootPainScale extends StatelessWidget {
  const _FootPainScale({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int? value;
  final ValueChanged<int> onChanged;

  int _valueFor(Offset position, double width) {
    const inset = 18.0;
    final fraction = ((position.dx - inset) / (width - inset * 2)).clamp(
      0.0,
      1.0,
    );
    return (1 + (fraction * 9).round()).clamp(1, 10).toInt();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      void select(Offset position) =>
          onChanged(_valueFor(position, constraints.maxWidth));
      return Semantics(
        slider: true,
        label: 'Pain level',
        value: value == null ? '未選択' : 'LV.$value /10',
        increasedValue: value == null || value! >= 10
            ? null
            : 'LV.${value! + 1} /10',
        decreasedValue: value == null || value! <= 1
            ? null
            : 'LV.${value! - 1} /10',
        onIncrease: value == null || value! >= 10
            ? null
            : () => onChanged(value! + 1),
        onDecrease: value == null || value! <= 1
            ? null
            : () => onChanged(value! - 1),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => select(details.localPosition),
          onHorizontalDragUpdate: (details) => select(details.localPosition),
          child: SizedBox(
            height: 58,
            width: double.infinity,
            child: CustomPaint(
              painter: _FootPainScalePainter(
                value: value,
                colors: Theme.of(context).colorScheme,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _FootPainScalePainter extends CustomPainter {
  const _FootPainScalePainter({required this.value, required this.colors});

  final int? value;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 18.0;
    final y = 22.0;
    final start = Offset(inset, y);
    final end = Offset(size.width - inset, y);
    final track = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7
      ..color = colors.outlineVariant.withValues(alpha: .28);
    canvas.drawLine(start, end, track);
    final selectedFraction = value == null ? 0.0 : (value! - 1) / 9;
    final selected = Offset.lerp(start, end, selectedFraction)!;
    if (value != null) {
      track.color = colors.primary.withValues(alpha: .78);
      canvas.drawLine(start, selected, track);
    }
    final tick = Paint()
      ..strokeWidth = 1
      ..color = colors.onSurfaceVariant.withValues(alpha: .58);
    final textStyle = TextStyle(
      color: colors.onSurfaceVariant.withValues(alpha: .76),
      fontSize: 11,
      fontFamily: 'ShareTechMono',
    );
    for (var index = 0; index < 10; index++) {
      final position = Offset.lerp(start, end, index / 9)!;
      final selectedTick = value == index + 1;
      tick
        ..strokeWidth = selectedTick ? 2 : 1
        ..color = (selectedTick ? colors.primary : colors.onSurfaceVariant)
            .withValues(alpha: selectedTick ? 1 : .58);
      canvas.drawLine(
        Offset(position.dx, y - (selectedTick ? 10 : 7)),
        Offset(position.dx, y + (selectedTick ? 10 : 7)),
        tick,
      );
      if (selectedTick) {
        canvas.drawCircle(position, 5, Paint()..color = colors.primary);
      }
      final label = TextPainter(
        text: TextSpan(text: '${index + 1}', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(position.dx - label.width / 2, 40));
    }
  }

  @override
  bool shouldRepaint(covariant _FootPainScalePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.colors != colors;
}
