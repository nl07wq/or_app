import 'package:flutter/cupertino.dart';
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
    this.calendarStyle = false,
  });

  final NotificationConfiguration value;
  final ValueChanged<NotificationConfiguration> onChanged;

  /// Schedule editing uses a compact iPhone Calendar-like selector while the
  /// standalone reminder editor retains its existing inline controls.
  final bool calendarStyle;

  @override
  State<SharedNotificationEditor> createState() =>
      _SharedNotificationEditorState();
}

class _SharedNotificationEditorState extends State<SharedNotificationEditor> {
  static const _presets = [0, 5, 15, 30, 60, 1440, 10080];
  static const _calendarPresetOffsets = {0, 10, 60, 360};
  final _number = TextEditingController();
  late final Set<int> _calendarCustomOffsets = {
    ...widget.value.offsetsMinutes.where(
      (offset) => !_calendarPresetOffsets.contains(offset),
    ),
  };
  var _unit = NotificationOffsetUnit.minutes;
  String? _error;

  @override
  void didUpdateWidget(covariant SharedNotificationEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.calendarStyle) return;
    // A parent rebuild follows every selection change. Keep deselected custom
    // choices available for this edit session while admitting any persisted
    // custom offset supplied by an externally refreshed record.
    _calendarCustomOffsets.addAll(
      widget.value.offsetsMinutes.where(
        (offset) => !_calendarPresetOffsets.contains(offset),
      ),
    );
  }

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

  Future<void> _showCalendarSelector() {
    final selected = widget.value.offsetsMinutes.toSet();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void toggle(int offset) {
            selected.contains(offset)
                ? selected.remove(offset)
                : selected.add(offset);
            widget.onChanged(widget.value.copyWith(offsetsMinutes: selected));
            setSheetState(() {});
          }

          void addCustom(int offset) {
            if (!_calendarPresetOffsets.contains(offset)) {
              setState(() => _calendarCustomOffsets.add(offset));
            }
            // Adding an existing offset must select it; it must not invert an
            // already selected option as the generic toggle would.
            selected.add(offset);
            widget.onChanged(widget.value.copyWith(offsetsMinutes: selected));
            setSheetState(() {});
          }

          final customOffsets = _calendarCustomOffsets.toList()..sort();

          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: .68,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text('リマインダー', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  for (final preset in const <(String, int)>[
                    ('開始時刻', 0),
                    ('10分前', 10),
                    ('1時間前', 60),
                    ('6時間前', 360),
                  ])
                    ListTile(
                      key: ValueKey(
                        'calendar-notification-preset-${preset.$2}',
                      ),
                      contentPadding: EdgeInsets.zero,
                      title: Text(preset.$1),
                      trailing: selected.contains(preset.$2)
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => toggle(preset.$2),
                    ).inputFeedback(),
                  const Divider(),
                  for (final offset in customOffsets)
                    ListTile(
                      key: ValueKey('calendar-notification-custom-$offset'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(notificationOffsetLabel(offset)),
                      trailing: selected.contains(offset)
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => toggle(offset),
                    ).inputFeedback(),
                  ListTile(
                    key: const ValueKey('calendar-notification-custom'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('カスタム時刻…'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showCalendarCustomPicker(
                      sheetContext,
                      onConfirm: addCustom,
                    ),
                  ).inputFeedback(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCalendarCustomPicker(
    BuildContext sheetContext, {
    required ValueChanged<int> onConfirm,
  }) async {
    var number = 10;
    var unit = NotificationOffsetUnit.minutes;
    await showModalBottomSheet<void>(
      context: sheetContext,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 310,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                  TextButton(
                    key: const ValueKey('calendar-notification-custom-confirm'),
                    onPressed: () {
                      onConfirm(canonicalNotificationOffset(number, unit));
                      Navigator.pop(context);
                    },
                    child: const Text('完了'),
                  ),
                ],
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 36,
                        onSelectedItemChanged: (index) => number = index + 1,
                        children: [
                          for (var value = 1; value <= 60; value++)
                            Center(child: Text('$value')),
                        ],
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        itemExtent: 36,
                        onSelectedItemChanged: (index) =>
                            unit = NotificationOffsetUnit.values[index],
                        children: [
                          for (final value in NotificationOffsetUnit.values)
                            Center(child: Text(value.label)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.calendarStyle
      ? _buildCalendarField(context)
      : Column(
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

  Widget _buildCalendarField(BuildContext context) {
    final labels = widget.value.offsetsMinutes
        .map(notificationOffsetLabel)
        .join('、');
    return ListTile(
      key: const ValueKey('calendar-notification-field'),
      contentPadding: EdgeInsets.zero,
      title: const Text('リマインダー'),
      subtitle: Text(labels.isEmpty ? 'なし' : labels),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showCalendarSelector,
    ).inputFeedback();
  }
}
