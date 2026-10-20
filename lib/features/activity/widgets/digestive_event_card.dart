import 'package:flutter/material.dart';

import 'package:or_app/core/widgets/global_touch_ripple.dart';

import '../../../core/models/digestive_event.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dashboard_glass_card.dart';
import '../models/activity_draft.dart';

class DigestiveEventCard extends StatelessWidget {
  final ActivityDraftDigestiveEvent event;
  final ValueChanged<ActivityDraftDigestiveEvent> onChanged;
  final VoidCallback onDelete;
  final bool enabled;

  const DigestiveEventCard({
    super.key,
    required this.event,
    required this.onChanged,
    required this.onDelete,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '排便イベント${event.sequence}',
      container: true,
      child: DashboardGlassCard(
        key: ValueKey('digestive-event-${event.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'DIGESTIVE ${event.sequence}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Semantics(
                  label: '排便イベント${event.sequence}を削除',
                  button: true,
                  child: IconButton(
                    key: ValueKey('delete-digestive-${event.id}'),
                    tooltip: '排便イベント${event.sequence}を削除',
                    onPressed: enabled ? onDelete : null,
                    icon: const Icon(Icons.delete_outline),
                  ).actionableFeedback(),
                ),
              ],
            ),
            AppSpacing.gapMD,
            _ChoiceSection(
              semanticsLabel: '量',
              title: 'Amount',
              children: [
                for (final option in const [
                  (value: 0, label: 'なし'),
                  (value: 1, label: '少量'),
                  (value: 2, label: '普通'),
                  (value: 3, label: '多量'),
                ])
                  _EventChoiceChip(
                    key: ValueKey(
                      'digestive-${event.id}-amount-${option.value}',
                    ),
                    label: option.label,
                    selected: event.amount == option.value,
                    enabled: enabled,
                    onSelected: () => onChanged(
                      _copyEvent(
                        event,
                        amount: option.value,
                        clearShapeAndRelief: option.value == 0,
                      ),
                    ),
                  ),
              ],
            ),
            if (event.amount != 0) ...[
              AppSpacing.gapLG,
              _ChoiceSection(
                semanticsLabel: '形状',
                title: 'Shape',
                children: [
                  _EventChoiceChip(
                    key: ValueKey('digestive-${event.id}-shape-1'),
                    icon: Icons.hexagon,
                    label: DigestiveEvent.shapeLabel(1),
                    selected: event.shape == 1,
                    enabled: enabled,
                    onSelected: () => onChanged(_copyEvent(event, shape: 1)),
                  ),
                  _EventChoiceChip(
                    key: ValueKey('digestive-${event.id}-shape-2'),
                    icon: Icons.circle,
                    label: DigestiveEvent.shapeLabel(2),
                    selected: event.shape == 2,
                    enabled: enabled,
                    onSelected: () => onChanged(_copyEvent(event, shape: 2)),
                  ),
                  _EventChoiceChip(
                    key: ValueKey('digestive-${event.id}-shape-3'),
                    icon: Icons.water_drop,
                    label: DigestiveEvent.shapeLabel(3),
                    selected: event.shape == 3,
                    enabled: enabled,
                    onSelected: () => onChanged(_copyEvent(event, shape: 3)),
                  ),
                ],
              ),
              AppSpacing.gapLG,
              _ReliefChoiceSection(
                semanticsLabel: 'スッキリ感',
                title: 'Relief',
                children: [
                  _ReliefChoiceButton(
                    key: ValueKey('digestive-${event.id}-relief-0'),
                    icon: Icons.sentiment_dissatisfied,
                    label: '残便感',
                    selected: event.relief == 0,
                    enabled: enabled,
                    onSelected: () => onChanged(_copyEvent(event, relief: 0)),
                  ),
                  _ReliefChoiceButton(
                    key: ValueKey('digestive-${event.id}-relief-1'),
                    icon: Icons.sentiment_neutral,
                    label: DigestiveEvent.reliefLabel(1),
                    selected: event.relief == 1,
                    enabled: enabled,
                    onSelected: () => onChanged(_copyEvent(event, relief: 1)),
                  ),
                  _ReliefChoiceButton(
                    key: ValueKey('digestive-${event.id}-relief-2'),
                    icon: Icons.sentiment_satisfied,
                    label: DigestiveEvent.reliefLabel(2),
                    selected: event.relief == 2,
                    enabled: enabled,
                    onSelected: () => onChanged(_copyEvent(event, relief: 2)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChoiceSection extends StatelessWidget {
  final String semanticsLabel;
  final String title;
  final List<Widget> children;

  const _ChoiceSection({
    required this.semanticsLabel,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          AppSpacing.gapSM,
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

/// Relief has exactly three short semantic values. Keeping it in a dedicated
/// row avoids Wrap producing an uneven second line on narrow activity cards.
class _ReliefChoiceSection extends StatelessWidget {
  const _ReliefChoiceSection({
    required this.semanticsLabel,
    required this.title,
    required this.children,
  });

  final String semanticsLabel;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    container: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        AppSpacing.gapSM,
        SizedBox(
          height: 46,
          child: Row(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                Expanded(child: children[index]),
                if (index != children.length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _EventChoiceChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelected;

  const _EventChoiceChip({
    super.key,
    this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: ChoiceChip(
        showCheckmark: true,
        avatar: icon == null ? null : Icon(icon, size: 18),
        label: ExcludeSemantics(child: Text(label)),
        selected: selected,
        onSelected: enabled ? (_) => onSelected() : null,
      ).inputFeedback(),
    );
  }
}

class _ReliefChoiceButton extends StatelessWidget {
  const _ReliefChoiceButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final labelSize = textScale > 1.15 ? 12.0 : 13.0;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: .82)
            : scheme.surfaceContainerHighest.withValues(alpha: .36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected
                ? scheme.primary.withValues(alpha: .88)
                : scheme.outline.withValues(alpha: .34),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onSelected : null,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: labelSize,
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 2),
                    Icon(Icons.check, size: 12, color: foreground),
                  ],
                ],
              ),
            ),
          ),
        ),
      ).inputFeedback(),
    );
  }
}

ActivityDraftDigestiveEvent _copyEvent(
  ActivityDraftDigestiveEvent event, {
  int? amount,
  int? shape,
  int? relief,
  bool clearShapeAndRelief = false,
}) {
  return ActivityDraftDigestiveEvent(
    id: event.id,
    sequence: event.sequence,
    amount: amount ?? event.amount,
    shape: clearShapeAndRelief ? null : shape ?? event.shape,
    relief: clearShapeAndRelief ? null : relief ?? event.relief,
    recordedAt: event.recordedAt,
  );
}
