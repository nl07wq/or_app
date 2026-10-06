import 'package:flutter/material.dart';

import '../../../core/widgets/global_touch_ripple.dart';
import '../models/notification_configuration.dart';

/// The single notification-offset editor used by both Schedule and Reminder.
/// Editing is intentionally silent; the parent editor's formal save remains
/// the only command action.
class SharedNotificationEditor extends StatefulWidget {
  const SharedNotificationEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final NotificationConfiguration value;
  final ValueChanged<NotificationConfiguration> onChanged;

  @override
  State<SharedNotificationEditor> createState() =>
      _SharedNotificationEditorState();
}

class _SharedNotificationEditorState extends State<SharedNotificationEditor> {
  static const _presets = [0, 5, 15, 30, 60, 1440, 10080];
  final _number = TextEditingController();
  var _unit = NotificationOffsetUnit.minutes;
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  void _toggle(int minutes) {
    final next = widget.value.offsetsMinutes.toSet();
    next.contains(minutes) ? next.remove(minutes) : next.add(minutes);
    widget.onChanged(widget.value.copyWith(offsetsMinutes: next));
  }

  void _addCustom() {
    final number = int.tryParse(_number.text.trim());
    if (number == null || number < 0 || number > 525600) {
      setState(() => _error = '0以上の数値を入力してください。');
      return;
    }
    final minutes = canonicalNotificationOffset(number, _unit);
    widget.onChanged(
      widget.value.copyWith(
        offsetsMinutes: {...widget.value.offsetsMinutes, minutes},
      ),
    );
    setState(() {
      _number.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('shared-notification-editor'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('通知', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final offset in _presets)
            FilterChip(
              key: ValueKey('notification-preset-$offset'),
              label: Text(notificationOffsetLabel(offset)),
              selected: widget.value.offsetsMinutes.contains(offset),
              onSelected: (_) => _toggle(offset),
            ).inputFeedback(),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('notification-custom-number'),
              controller: _number,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'カスタム'),
            ).inputFeedback(),
          ),
          const SizedBox(width: 8),
          DropdownButton<NotificationOffsetUnit>(
            key: const ValueKey('notification-custom-unit'),
            value: _unit,
            items: [
              for (final unit in NotificationOffsetUnit.values)
                DropdownMenuItem(value: unit, child: Text(unit.label)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _unit = value);
            },
          ).inputFeedback(),
          IconButton(
            key: const ValueKey('notification-custom-add'),
            tooltip: '通知を追加',
            onPressed: _addCustom,
            icon: const Icon(Icons.add_alert_outlined),
          ).inputFeedback(),
        ],
      ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (widget.value.offsetsMinutes.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final offset in widget.value.offsetsMinutes)
              InputChip(
                key: ValueKey('notification-offset-$offset'),
                label: Text(notificationOffsetLabel(offset)),
                onDeleted: () => _toggle(offset),
              ).inputFeedback(),
          ],
        ),
      ],
      const SizedBox(height: 4),
      Text('TIMEZONE  ${widget.value.timeZone}'),
    ],
  );
}
