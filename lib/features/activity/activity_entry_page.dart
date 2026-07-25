import 'package:flutter/material.dart';

import '../../core/models/activity_data.dart';
import '../../core/models/bowel_movement_record.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/services/app_clock.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/operation_text_field.dart';
import '../../core/widgets/section_header.dart';
import 'models/activity_summary_state.dart';

enum _EditableStepField { measuredSteps, carryOver }

class ActivityEntryPage extends StatefulWidget {
  final ActivityData? initialData;
  final DateTime? targetDate;

  const ActivityEntryPage({super.key, this.initialData, this.targetDate});

  @override
  State<ActivityEntryPage> createState() => _ActivityEntryPageState();
}

class _ActivityEntryPageState extends State<ActivityEntryPage> {
  late DateTime _date;
  late final TextEditingController _measuredStepsController;
  late final TextEditingController _carryOverController;
  late final FocusNode _measuredStepsFocusNode;
  late final FocusNode _carryOverFocusNode;
  late BowelMovementStatus _bowelStatus;
  late final TextEditingController _bowelCountController;
  late final TextEditingController _bowelAmountController;
  late final TextEditingController _bowelShapeController;
  late final TextEditingController _bowelTimeController;
  late final TextEditingController _bowelNoteController;
  int _previousCarryOverDeduction = 0;
  _EditableStepField _lastFocusedField = _EditableStepField.measuredSteps;

  @override
  void initState() {
    super.initState();
    _date = widget.initialData?.date ?? widget.targetDate ?? AppClock.today();
    _measuredStepsController = TextEditingController(
      text: widget.initialData?.measuredSteps.toString() ?? '',
    );
    _carryOverController = TextEditingController(
      text: widget.initialData?.carryOver.toString() ?? '0',
    );
    _measuredStepsFocusNode = FocusNode();
    _carryOverFocusNode = FocusNode();
    final bowelMovement =
        widget.initialData?.bowelMovement ??
        const BowelMovementRecord.unconfirmed();
    _bowelStatus = bowelMovement.status;
    _bowelCountController = TextEditingController(
      text: bowelMovement.count?.toString() ?? '',
    );
    _bowelAmountController = TextEditingController(
      text: bowelMovement.amount?.toString() ?? '',
    );
    _bowelShapeController = TextEditingController(
      text: bowelMovement.shape?.toString() ?? '',
    );
    _bowelTimeController = TextEditingController(
      text: bowelMovement.time == null
          ? ''
          : '${bowelMovement.time!.hour.toString().padLeft(2, '0')}:'
                '${bowelMovement.time!.minute.toString().padLeft(2, '0')}',
    );
    _bowelNoteController = TextEditingController(
      text: bowelMovement.note ?? '',
    );
    _measuredStepsFocusNode.addListener(
      () => _updateFocusedField(
        _measuredStepsFocusNode,
        _EditableStepField.measuredSteps,
      ),
    );
    _carryOverFocusNode.addListener(
      () => _updateFocusedField(
        _carryOverFocusNode,
        _EditableStepField.carryOver,
      ),
    );
    _loadPreviousCarryOver(_date);
  }

  @override
  void dispose() {
    _measuredStepsController.dispose();
    _carryOverController.dispose();
    _measuredStepsFocusNode.dispose();
    _carryOverFocusNode.dispose();
    _bowelCountController.dispose();
    _bowelAmountController.dispose();
    _bowelShapeController.dispose();
    _bowelTimeController.dispose();
    _bowelNoteController.dispose();
    super.dispose();
  }

  void _updateFocusedField(FocusNode node, _EditableStepField field) {
    if (node.hasFocus) _lastFocusedField = field;
  }

  Future<void> _loadPreviousCarryOver(DateTime date) async {
    final previous = await loadPreviousActivity(date);
    if (!mounted || !_isSameDate(_date, date)) return;

    setState(() {
      _previousCarryOverDeduction = previous?.carryOver ?? 0;
    });
  }

  int? get _measuredSteps => int.tryParse(_measuredStepsController.text.trim());

  int? get _carryOver {
    final text = _carryOverController.text.trim();
    return text.isEmpty ? 0 : int.tryParse(text);
  }

  int? get _officialSteps {
    final measuredSteps = _measuredSteps;
    final carryOver = _carryOver;
    if (measuredSteps == null || carryOver == null) return null;

    final officialSteps =
        measuredSteps + carryOver - _previousCarryOverDeduction;
    return officialSteps < 0 ? null : officialSteps;
  }

  Future<void> _save() async {
    final measuredSteps = _measuredSteps;
    final carryOver = _carryOver;
    final officialSteps = _officialSteps;

    if (measuredSteps == null ||
        measuredSteps < 0 ||
        carryOver == null ||
        carryOver < 0 ||
        officialSteps == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter valid values that result in non-negative official steps.',
          ),
        ),
      );
      return;
    }

    final bowelMovement = _buildBowelMovement();
    if (bowelMovement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid bowel count and optional HH:mm time.'),
        ),
      );
      return;
    }

    try {
      final initial = widget.initialData;
      await saveActivity(
        initial == null
            ? ActivityData(
                date: _date,
                measuredSteps: measuredSteps,
                carryOver: carryOver,
                bowelMovement: bowelMovement,
              )
            : initial.copyWith(
                date: _date,
                measuredSteps: measuredSteps,
                carryOver: carryOver,
                stepsEntered: true,
                carryOverEntered: true,
                bowelMovement: bowelMovement,
                updatedAt: DateTime.now(),
              ),
      );
    } on ConfirmedDailyLogException catch (error) {
      if (mounted) showConfirmedLogMessage(context, error);
      return;
    } on ArgumentError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Official steps cannot be negative. Review Carry Over values.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.popUntil(context, ModalRoute.withName(AppRoutes.dashboard));
  }

  Future<void> _pickDate() async {
    if (widget.initialData != null) return;

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (picked == null) return;

    setState(() {
      _date = picked;
      _previousCarryOverDeduction = 0;
    });
    await _loadPreviousCarryOver(picked);
  }

  void _addQuickSteps(int amount) {
    final controller = _lastFocusedField == _EditableStepField.measuredSteps
        ? _measuredStepsController
        : _carryOverController;
    final focusNode = _lastFocusedField == _EditableStepField.measuredSteps
        ? _measuredStepsFocusNode
        : _carryOverFocusNode;
    final current = int.tryParse(controller.text.trim()) ?? 0;
    final text = (current + amount).toString();

    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    focusNode.requestFocus();
    setState(() {});
  }

  BowelMovementRecord? _buildBowelMovement() {
    final note = _bowelNoteController.text.trim();
    final timeText = _bowelTimeController.text.trim();
    final time = _parseOptionalTime(timeText);
    if (timeText.isNotEmpty && time == null) return null;

    switch (_bowelStatus) {
      case BowelMovementStatus.unconfirmed:
        return const BowelMovementRecord.unconfirmed();
      case BowelMovementStatus.none:
        return BowelMovementRecord.none(
          time: time,
          note: note.isEmpty ? null : note,
        );
      case BowelMovementStatus.recorded:
        final count = int.tryParse(_bowelCountController.text.trim());
        if (count == null || count <= 0) {
          final existing = widget.initialData?.bowelMovement;
          if (existing?.status == BowelMovementStatus.recorded &&
              existing?.count == null &&
              _bowelCountController.text.trim().isEmpty) {
            return existing;
          }
          return null;
        }
        return BowelMovementRecord.recorded(
          count: count,
          amount: _optionalInt(_bowelAmountController.text),
          shape: _optionalInt(_bowelShapeController.text),
          time: time,
          note: note.isEmpty ? null : note,
        );
    }
  }

  int? _optionalInt(String text) {
    final value = text.trim();
    return value.isEmpty ? null : int.tryParse(value);
  }

  DateTime? _parseOptionalTime(String text) {
    if (text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return DateTime(_date.year, _date.month, _date.day, hour, minute);
  }

  @override
  Widget build(BuildContext context) {
    final officialSteps = _officialSteps;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialData == null ? 'Activity Entry' : 'Edit Activity',
        ),
      ),
      body: Padding(
        padding: AppSpacing.cardPadding,
        child: SingleChildScrollView(
          child: OperationCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  icon: Icons.directions_walk_outlined,
                  title: 'DAILY ACTIVITY',
                ),
                AppSpacing.gapMD,
                ListTile(
                  title: const Text('Date'),
                  trailing: Text(_formatDate(_date)),
                  onTap: _pickDate,
                ),
                AppSpacing.gapMD,
                OperationTextField(
                  controller: _measuredStepsController,
                  focusNode: _measuredStepsFocusNode,
                  label: 'Measured steps',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                AppSpacing.gapMD,
                OperationTextField(
                  controller: _carryOverController,
                  focusNode: _carryOverFocusNode,
                  label: 'Carry Over',
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                AppSpacing.gapMD,
                _ReadOnlyStepDisplay(
                  label: 'Previous day Carry Over deduction',
                  value: _previousCarryOverDeduction,
                  prefix: '-',
                ),
                AppSpacing.gapMD,
                _OfficialStepsDisplay(officialSteps: officialSteps),
                AppSpacing.gapLG,
                const SectionHeader(
                  icon: Icons.health_and_safety_outlined,
                  title: 'BOWEL MOVEMENT',
                ),
                AppSpacing.gapMD,
                DropdownButtonFormField<BowelMovementStatus>(
                  initialValue: _bowelStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(
                      value: BowelMovementStatus.unconfirmed,
                      child: Text('Not entered'),
                    ),
                    DropdownMenuItem(
                      value: BowelMovementStatus.none,
                      child: Text('No bowel movement'),
                    ),
                    DropdownMenuItem(
                      value: BowelMovementStatus.recorded,
                      child: Text('Recorded'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _bowelStatus = value);
                  },
                ),
                if (_bowelStatus == BowelMovementStatus.recorded) ...[
                  AppSpacing.gapMD,
                  OperationTextField(
                    controller: _bowelCountController,
                    label: 'Count',
                    keyboardType: TextInputType.number,
                  ),
                  AppSpacing.gapMD,
                  OperationTextField(
                    controller: _bowelAmountController,
                    label: 'Amount (optional)',
                    keyboardType: TextInputType.number,
                  ),
                  AppSpacing.gapMD,
                  OperationTextField(
                    controller: _bowelShapeController,
                    label: 'Shape (optional)',
                    keyboardType: TextInputType.number,
                  ),
                ],
                if (_bowelStatus != BowelMovementStatus.unconfirmed) ...[
                  AppSpacing.gapMD,
                  OperationTextField(
                    controller: _bowelTimeController,
                    label: 'Time HH:mm (optional)',
                    keyboardType: TextInputType.datetime,
                  ),
                  AppSpacing.gapMD,
                  OperationTextField(
                    controller: _bowelNoteController,
                    label: 'Bowel note (optional)',
                  ),
                ],
                AppSpacing.gapMD,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [500, 1000, 2000, 5000]
                      .map(
                        (value) => OutlinedButton(
                          onPressed: () => _addQuickSteps(value),
                          child: Text('+$value'),
                        ),
                      )
                      .toList(),
                ),
                AppSpacing.gapLG,
                OperationButton(
                  icon: Icons.save_outlined,
                  text: 'Save Activity',
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _ReadOnlyStepDisplay extends StatelessWidget {
  final String label;
  final int value;
  final String prefix;

  const _ReadOnlyStepDisplay({
    required this.label,
    required this.value,
    required this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text('$prefix${_formatSteps(value)} steps'),
    );
  }
}

class _OfficialStepsDisplay extends StatelessWidget {
  final int? officialSteps;

  const _OfficialStepsDisplay({required this.officialSteps});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Official steps'),
      child: Text(
        officialSteps == null ? '--' : '${_formatSteps(officialSteps!)} steps',
      ),
    );
  }
}

String _formatSteps(int steps) => steps.toString().replaceAllMapped(
  RegExp(r'(?<!^)(?=(\d{3})+$)'),
  (_) => ',',
);
