import 'package:flutter/material.dart';

import '../../../core/models/morning_data.dart';
import '../../../core/widgets/global_touch_ripple.dart';
import '../../../core/widgets/dashboard_glass_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../schedule/widgets/shared_time_picker.dart';

class RecoveryCard extends StatelessWidget {
  final TextEditingController sleepController;
  final TextEditingController sleepScoreController;
  final SleepType sleepType;
  final ValueChanged<SleepType> onSleepTypeChanged;
  final bool sleepTimeUnmeasured;
  final VoidCallback onSleepTimeUnmeasured;
  final VoidCallback onSleepTimeMeasured;
  final bool initiallyExpanded;

  const RecoveryCard({
    super.key,
    required this.sleepController,
    required this.sleepScoreController,
    required this.sleepType,
    required this.onSleepTypeChanged,
    required this.sleepTimeUnmeasured,
    required this.onSleepTimeUnmeasured,
    required this.onSleepTimeMeasured,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(icon: Icons.hotel, title: "RECOVERY"),
              ),
              _UnmeasuredToggle(
                key: const ValueKey('Sleep Time-unmeasured-toggle'),
                selected: sleepTimeUnmeasured,
                onPressed: sleepTimeUnmeasured
                    ? onSleepTimeMeasured
                    : onSleepTimeUnmeasured,
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text('睡眠タイプ', style: TextStyle(fontWeight: FontWeight.bold)),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SleepType.values
                .map(
                  (value) => ChoiceChip(
                    label: Text(value.displayLabel),
                    selected: sleepType == value,
                    onSelected: (selected) {
                      if (selected) onSleepTypeChanged(value);
                    },
                  ).inputFeedback(),
                )
                .toList(),
          ),

          const SizedBox(height: 20),

          if (sleepTimeUnmeasured)
            const _UnmeasuredValue(title: 'Sleep Time')
          else ...[
            _SleepDurationOrbitalInput(
              title: "Sleep Time",
              controller: sleepController,
              initiallyExpanded: initiallyExpanded,
            ),
          ],

          const SizedBox(height: 20),

          if (sleepTimeUnmeasured)
            const _UnmeasuredValue(title: 'Sleep Score')
          else if (sleepType == SleepType.sleep)
            _SleepScoreGauge(
              key: ValueKey('status-sleep-score-hud-${sleepType.name}'),
              title: "Sleep Score",
              controller: sleepScoreController,
              initiallyExpanded: initiallyExpanded,
            )
          else ...[
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'Sleep Score',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: null,
                  child: Text(
                    '仮眠',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.lightBlueAccent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SleepDurationOrbitalInput extends StatefulWidget {
  const _SleepDurationOrbitalInput({
    required this.title,
    required this.controller,
    required this.initiallyExpanded,
  });

  final String title;
  final TextEditingController controller;
  final bool initiallyExpanded;

  @override
  State<_SleepDurationOrbitalInput> createState() =>
      _SleepDurationOrbitalInputState();
}

class _SleepDurationOrbitalInputState
    extends State<_SleepDurationOrbitalInput> {
  late bool _collapsed;
  Duration get _duration {
    final parts = widget.controller.text.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return Duration(
      hours: hour < 0 ? 0 : hour,
      minutes: minute.clamp(0, 59).toInt(),
    );
  }

  @override
  void initState() {
    super.initState();
    _collapsed = !widget.initiallyExpanded && widget.controller.text.isNotEmpty;
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _selectDuration() async {
    final result = await showSharedDurationPicker(
      context,
      initialDuration: _duration,
    );
    if (!mounted || result == null) return;
    widget.controller.text =
        '${result.inHours}:${result.inMinutes.remainder(60).toString().padLeft(2, '0')}';
    setState(() => _collapsed = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_collapsed && widget.controller.text.isNotEmpty) {
      return _CollapsedRecoveryValue(
        key: const ValueKey('status-sleep-duration-picker'),
        label: widget.title,
        value: widget.controller.text,
        onTap: () => _selectDuration(),
      );
    }
    return Semantics(
      button: true,
      label: 'Sleep duration ${widget.controller.text}',
      child: InkWell(
        key: const ValueKey('status-sleep-duration-picker'),
        onTap: _selectDuration,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: colors.surfaceContainer.withValues(alpha: .28),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.primary.withValues(alpha: .38)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(Icons.bedtime_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Text('時間・分', style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
              Text(
                widget.controller.text,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFamily: 'ShareTechMono',
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right, color: colors.primary),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ).inputFeedback(),
    );
  }
}

class _SleepScoreGauge extends StatefulWidget {
  const _SleepScoreGauge({
    super.key,
    required this.title,
    required this.controller,
    required this.initiallyExpanded,
  });
  final String title;
  final TextEditingController controller;
  final bool initiallyExpanded;
  @override
  State<_SleepScoreGauge> createState() => _SleepScoreGaugeState();
}

class _SleepScoreGaugeState extends State<_SleepScoreGauge> {
  int _value = 80;
  late bool _editing;
  @override
  void initState() {
    super.initState();
    _editing =
        widget.initiallyExpanded ||
        int.tryParse(widget.controller.text) == null;
    _read();
    widget.controller.addListener(_read);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_read);
    super.dispose();
  }

  void _read() {
    final v = (int.tryParse(widget.controller.text) ?? _value).clamp(0, 100);
    if (v != _value && mounted) setState(() => _value = v);
  }

  void _set(double v) =>
      widget.controller.text = v.round().clamp(0, 100).toString();
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    if (!_editing && widget.controller.text.isNotEmpty) {
      return _CollapsedRecoveryValue(
        key: const ValueKey('status-sleep-score-collapsed'),
        label: widget.title,
        value: '$_value',
        onTap: () => setState(() => _editing = true),
      );
    }
    return SizedBox(
      height: 144,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 5),
          Expanded(
            child: Row(
              children: [
                Text(
                  '$_value',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontFamily: 'ShareTechMono',
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text('/100', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(width: 14),
                Expanded(
                  child: LayoutBuilder(
                    builder: (ctx, b) => Semantics(
                      slider: true,
                      label: 'Sleep score $_value',
                      child: GestureDetector(
                        onTapDown: (d) =>
                            _set(d.localPosition.dx / b.maxWidth * 100),
                        onHorizontalDragUpdate: (d) =>
                            _set(d.localPosition.dx / b.maxWidth * 100),
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _ScoreGaugePainter(_value, c.primary),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey('status-sleep-score-done'),
              onPressed: () => setState(() => _editing = false),
              child: const Text('完了'),
            ).actionableFeedback(role: ActionableFeedbackRole.cursor),
          ),
        ],
      ),
    );
  }
}

class _CollapsedRecoveryValue extends StatelessWidget {
  const _CollapsedRecoveryValue({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: '$label $value 再編集',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 54,
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
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'ShareTechMono',
                ),
              ),
              Icon(Icons.edit_outlined, size: 18, color: color),
            ],
          ),
        ),
      ).inputFeedback(),
    );
  }
}

class _ScoreGaugePainter extends CustomPainter {
  const _ScoreGaugePainter(this.value, this.color);
  final int value;
  final Color color;
  @override
  void paint(Canvas c, Size s) {
    final y = s.height / 2,
        p = Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 8
          ..color = color.withValues(alpha: .12);
    c.drawLine(Offset(0, y), Offset(s.width, y), p);
    p.color = color.withValues(alpha: .8);
    c.drawLine(Offset(0, y), Offset(s.width * value / 100, y), p);
    for (var i = 0; i <= 10; i++) {
      final x = s.width * i / 10;
      p
        ..strokeWidth = i == 0 || i == 5 || i == 10 ? 1.5 : 1
        ..color = color.withValues(alpha: (i * 10 <= value) ? .65 : .25);
      c.drawLine(Offset(x, y - 12), Offset(x, y + 12), p);
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreGaugePainter o) =>
      o.value != value || o.color != color;
}

class _UnmeasuredToggle extends StatelessWidget {
  const _UnmeasuredToggle({
    super.key,
    required this.selected,
    required this.onPressed,
  });

  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: const Text('未計測'),
    selected: selected,
    onSelected: (_) => onPressed(),
  ).inputFeedback();
}

class _UnmeasuredValue extends StatelessWidget {
  const _UnmeasuredValue({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '未計測',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.lightBlueAccent,
          ),
        ),
      ),
    ],
  );
}
