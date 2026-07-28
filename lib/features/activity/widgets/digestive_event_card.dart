import 'package:flutter/material.dart';

import '../../../core/models/digestive_event.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
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
      child: OperationCard(
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
                  ),
                ),
              ],
            ),
            AppSpacing.gapMD,
            _ChoiceSection(
              semanticsLabel: '量',
              title: 'Amount',
              children: [
                for (final option in const [
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
                    onSelected: () =>
                        onChanged(_copyEvent(event, amount: option.value)),
                  ),
              ],
            ),
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
            _ChoiceSection(
              semanticsLabel: 'スッキリ感',
              title: 'Relief',
              children: [
                _EventChoiceChip(
                  key: ValueKey('digestive-${event.id}-relief-0'),
                  icon: Icons.sentiment_dissatisfied,
                  label: '残便感',
                  selected: event.relief == 0,
                  enabled: enabled,
                  onSelected: () => onChanged(_copyEvent(event, relief: 0)),
                ),
                _EventChoiceChip(
                  key: ValueKey('digestive-${event.id}-relief-1'),
                  icon: Icons.sentiment_neutral,
                  label: DigestiveEvent.reliefLabel(1),
                  selected: event.relief == 1,
                  enabled: enabled,
                  onSelected: () => onChanged(_copyEvent(event, relief: 1)),
                ),
                _EventChoiceChip(
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
      ),
    );
  }
}

ActivityDraftDigestiveEvent _copyEvent(
  ActivityDraftDigestiveEvent event, {
  int? amount,
  int? shape,
  int? relief,
}) {
  return ActivityDraftDigestiveEvent(
    id: event.id,
    sequence: event.sequence,
    amount: amount ?? event.amount,
    shape: shape ?? event.shape,
    relief: relief ?? event.relief,
    recordedAt: event.recordedAt,
  );
}
