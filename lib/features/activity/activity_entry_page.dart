import 'package:flutter/material.dart';

import '../../core/models/activity_data.dart';
import '../../core/models/bowel_movement_record.dart';
import '../../core/models/digestive_event.dart';
import '../../core/models/morning_data.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/repositories/morning_repository.dart';
import '../../core/services/app_clock.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/services/persistence_access.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
import '../../core/widgets/operation_text_field.dart';
import '../../core/widgets/section_header.dart';
import '../repositories/app_repository_container.dart';
import 'models/activity_draft.dart';
import 'models/activity_summary_state.dart';
import 'repository/activity_repository.dart';
import 'services/activity_draft_finalize_service.dart';
import 'services/bowel_movement_resolver.dart';
import 'widgets/bowel_card.dart';
import 'widgets/digestive_event_card.dart';

enum _EditableStepField { measuredSteps, carryOver }

enum _EntryMode { loading, locked, draft, formal, error }

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
  late final TextEditingController _bowelAmountController;
  late final TextEditingController _bowelShapeController;
  int _previousCarryOverDeduction = 0;
  _EditableStepField _lastFocusedField = _EditableStepField.measuredSteps;
  _EntryMode _mode = _EntryMode.loading;
  ActivityData? _formalData;
  ActivityDraft? _draft;
  List<ActivityDraftDigestiveEvent> _digestiveEvents = [];
  Object? _loadError;
  bool _hasDraftConflict = false;
  bool _isBusy = false;
  int _eventIdSuffix = 0;

  bool get _isFormal => _mode == _EntryMode.formal;

  bool get _isToday => _isSameDate(_date, AppClock.today());

  bool get _usesDigestiveEvents =>
      !_isFormal || _formalData?.digestiveEvents != null;

  @override
  void initState() {
    super.initState();
    _date = widget.initialData?.date ?? widget.targetDate ?? AppClock.today();
    _measuredStepsController = TextEditingController();
    _carryOverController = TextEditingController(text: '0');
    _measuredStepsFocusNode = FocusNode();
    _carryOverFocusNode = FocusNode();
    _bowelAmountController = TextEditingController();
    _bowelShapeController = TextEditingController();
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
    _initializeForDate(_date, suppliedRecord: widget.initialData);
  }

  @override
  void dispose() {
    _measuredStepsController.dispose();
    _carryOverController.dispose();
    _measuredStepsFocusNode.dispose();
    _carryOverFocusNode.dispose();
    _bowelAmountController.dispose();
    _bowelShapeController.dispose();
    super.dispose();
  }

  Future<void> _initializeForDate(
    DateTime date, {
    ActivityData? suppliedRecord,
  }) async {
    if (mounted) {
      setState(() {
        _mode = _EntryMode.loading;
        _loadError = null;
        _hasDraftConflict = false;
      });
    }

    try {
      final confirmed = await DailyLogMutationGuard.isDateConfirmed(date);
      if (!mounted || !_isSameDate(_date, date)) return;
      if (confirmed) {
        setState(() => _mode = _EntryMode.locked);
        return;
      }

      final formal =
          suppliedRecord ??
          await const LocalActivityRepository().findByDate(date);
      ActivityDraft? draft;
      if (AppRepositoryRegistry.hasContainer) {
        draft = await AppRepositoryRegistry.container.activityDrafts.findByDate(
          date,
        );
      }
      if (!mounted || !_isSameDate(_date, date)) return;

      if (formal != null) {
        _applyFormalRecord(formal);
        setState(() {
          _formalData = formal;
          _draft = null;
          _hasDraftConflict = draft != null;
          _mode = _EntryMode.formal;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadLegacyBowel(date);
        });
      } else {
        _formalData = null;
        if (draft != null) {
          _applyDraft(draft);
        } else {
          _resetInput();
        }
        setState(() {
          _draft = draft;
          _mode = _EntryMode.draft;
        });
      }
      await _loadPreviousCarryOver(date);
    } catch (error) {
      if (!mounted || !_isSameDate(_date, date)) return;
      setState(() {
        _loadError = error;
        _mode = _EntryMode.error;
      });
    }
  }

  void _applyFormalRecord(ActivityData data) {
    _measuredStepsController.text = data.measuredSteps.toString();
    _carryOverController.text = data.carryOver.toString();
    final bowelMovement = data.bowelMovement;
    _bowelAmountController.text = switch (bowelMovement.status) {
      BowelMovementStatus.unconfirmed => '',
      BowelMovementStatus.none => '0',
      BowelMovementStatus.recorded => bowelMovement.amount?.toString() ?? '',
    };
    _bowelShapeController.text = _shapeControllerValue(bowelMovement.shape);
    _digestiveEvents = [
      for (final event in data.digestiveEvents ?? const <DigestiveEvent>[])
        ActivityDraftDigestiveEvent(
          id: event.id,
          sequence: event.sequence,
          amount: event.amount,
          shape: event.shape,
          relief: event.relief,
          recordedAt: event.recordedAt,
        ),
    ];
  }

  void _applyDraft(ActivityDraft draft) {
    _measuredStepsController.text = draft.measuredStepsInput;
    _carryOverController.text = draft.carryOverInput;
    _bowelAmountController.clear();
    _bowelShapeController.clear();
    _digestiveEvents = draft.digestiveEvents.toList();
  }

  void _resetInput() {
    _measuredStepsController.clear();
    _carryOverController.text = '0';
    _bowelAmountController.clear();
    _bowelShapeController.clear();
    _digestiveEvents = [];
    _draft = null;
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

  bool _validateSteps() {
    final measuredSteps = _measuredSteps;
    final carryOver = _carryOver;
    if (measuredSteps == null ||
        measuredSteps < 0 ||
        carryOver == null ||
        carryOver < 0 ||
        _officialSteps == null) {
      _showMessage(
        'Enter valid values that result in non-negative official steps.',
      );
      return false;
    }
    return true;
  }

  String? _digestiveValidationMessage() {
    for (final event in _digestiveEvents) {
      if (event.amount == null) {
        return '排便イベント${event.sequence}の量を入力してください';
      }
      if (event.shape == null) {
        return '排便イベント${event.sequence}の形状を入力してください';
      }
      if (event.relief == null) {
        return '排便イベント${event.sequence}のスッキリ感を入力してください';
      }
    }
    return null;
  }

  Future<void> _saveExisting() async {
    if (!_validateSteps()) return;
    final validationMessage = _usesDigestiveEvents
        ? _digestiveValidationMessage()
        : null;
    if (validationMessage != null) {
      _showMessage(validationMessage);
      return;
    }

    final initial = _formalData!;
    final updated = initial.copyWith(
      date: _date,
      measuredSteps: _measuredSteps!,
      carryOver: _carryOver!,
      stepsEntered: true,
      carryOverEntered: true,
      bowelMovement: _usesDigestiveEvents
          ? initial.bowelMovement
          : _buildBowelMovement(),
      digestiveEvents: _usesDigestiveEvents
          ? _buildFormalDigestiveEvents()
          : initial.digestiveEvents,
      updatedAt: DateTime.now(),
    );

    try {
      await saveActivity(updated);
    } on ConfirmedDailyLogException catch (error) {
      if (mounted) showConfirmedLogMessage(context, error);
      return;
    } on ArgumentError {
      _showMessage(
        'Official steps cannot be negative. Review Carry Over values.',
      );
      return;
    }

    if (!mounted) return;
    Navigator.popUntil(context, ModalRoute.withName(AppRoutes.dashboard));
  }

  Future<void> _saveDraft() async {
    if (_isBusy) return;
    if (!AppRepositoryRegistry.hasContainer) {
      _showMessage('一時保存に失敗しました');
      return;
    }
    setState(() => _isBusy = true);
    try {
      PersistenceAccess.requireWrite('activityDraft.save');
      final draft = _buildDraft();
      await AppRepositoryRegistry.container.activityDrafts.save(draft);
      final stored = await AppRepositoryRegistry.container.activityDrafts
          .findByDate(_date);
      if (!mounted) return;
      setState(() => _draft = stored ?? draft);
      _showMessage('一時保存しました');
    } catch (_) {
      if (mounted) _showMessage('一時保存に失敗しました');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _finalizeDraft() async {
    if (_isBusy || !_validateSteps()) return;
    final validationMessage = _digestiveValidationMessage();
    if (validationMessage != null) {
      _showMessage(validationMessage);
      return;
    }
    if (!AppRepositoryRegistry.hasContainer) {
      _showMessage('${_formatDate(_date)}のActivity記録を確定できませんでした');
      return;
    }

    setState(() => _isBusy = true);
    try {
      PersistenceAccess.requireWrite('activityDraft.finalize');
      final repository = AppRepositoryRegistry.container.activityDrafts;
      await repository.save(_buildDraft());
      final storedDraft = await repository.findByDate(_date);
      if (storedDraft == null) {
        throw StateError('Saved ACTIVITY Draft could not be reloaded.');
      }
      final saved = await ActivityDraftFinalizeService(
        AppRepositoryRegistry.container.database,
      ).finalize(draft: storedDraft);
      await refreshActivitySummary();
      if (!mounted) return;
      setState(() {
        _formalData = saved;
        _draft = null;
        _mode = _EntryMode.formal;
      });
      _showMessage('${_formatDate(_date)}のActivity記録を確定しました');
    } on ConfirmedDailyLogException catch (error) {
      if (mounted) showConfirmedLogMessage(context, error);
    } catch (_) {
      if (mounted) {
        _showMessage('${_formatDate(_date)}のActivity記録を確定できませんでした');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  ActivityDraft _buildDraft() {
    final now = DateTime.now().toUtc();
    return ActivityDraft(
      localDate: _formatDate(_date),
      measuredStepsInput: _measuredStepsController.text,
      carryOverInput: _carryOverController.text,
      digestiveEvents: _digestiveEvents,
      createdAt: _draft?.createdAt ?? now,
      updatedAt: now,
    );
  }

  List<DigestiveEvent> _buildFormalDigestiveEvents() {
    return DigestiveEvent.normalizeAndValidate([
      for (final event in _digestiveEvents)
        DigestiveEvent(
          id: event.id,
          sequence: event.sequence,
          amount: event.amount!,
          shape: event.shape!,
          relief: event.relief!,
          recordedAt: event.recordedAt,
        ),
    ]);
  }

  Future<void> _pickDate() async {
    if (_isFormal || _mode == _EntryMode.locked) return;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (picked == null || _isSameDate(picked, _date)) return;
    _date = picked;
    _previousCarryOverDeduction = 0;
    await _initializeForDate(picked);
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

  void _addDigestiveEvent() {
    final now = DateTime.now();
    final id =
        'digestive:${_formatDate(_date)}:'
        '${now.microsecondsSinceEpoch}:${_eventIdSuffix++}';
    setState(() {
      _digestiveEvents = [
        ..._digestiveEvents,
        ActivityDraftDigestiveEvent(
          id: id,
          sequence: _digestiveEvents.length + 1,
          recordedAt: now,
        ),
      ];
    });
  }

  void _updateDigestiveEvent(ActivityDraftDigestiveEvent updated) {
    setState(() {
      _digestiveEvents = [
        for (final event in _digestiveEvents)
          if (event.id == updated.id) updated else event,
      ];
    });
  }

  Future<void> _confirmDeleteDigestiveEvent(
    ActivityDraftDigestiveEvent event,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この排便イベントを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      final remaining = _digestiveEvents
          .where((candidate) => candidate.id != event.id)
          .toList();
      _digestiveEvents = [
        for (var index = 0; index < remaining.length; index++)
          ActivityDraftDigestiveEvent(
            id: remaining[index].id,
            sequence: index + 1,
            amount: remaining[index].amount,
            shape: remaining[index].shape,
            relief: remaining[index].relief,
            recordedAt: remaining[index].recordedAt,
          ),
      ];
    });
  }

  BowelMovementRecord _buildBowelMovement() {
    final amountText = _bowelAmountController.text.trim();
    if (amountText.isEmpty) {
      final existing = _formalData?.bowelMovement;
      if (existing?.status == BowelMovementStatus.recorded &&
          existing?.amount == null) {
        return existing!;
      }
      return const BowelMovementRecord.unconfirmed();
    }
    final amount = int.tryParse(amountText);
    if (amount == null || amount == 0) {
      return const BowelMovementRecord.none();
    }
    final shape = int.tryParse(_bowelShapeController.text.trim()) ?? 1;
    return BowelMovementRecord.recorded(amount: amount, shape: shape + 1);
  }

  Future<void> _loadLegacyBowel(DateTime date) async {
    if (_usesDigestiveEvents ||
        (_formalData?.bowelMovement.isConfirmed ?? false)) {
      return;
    }
    final records = await MorningRepository.getAll();
    MorningData? legacyMorning;
    for (final record in records) {
      final recordDate = DateTime.parse(record.date);
      if (_isSameDate(recordDate, date)) {
        legacyMorning = record;
        break;
      }
    }
    final bowelMovement = const BowelMovementResolver().resolve(
      legacyMorning: legacyMorning,
    );
    if (!mounted ||
        !_isSameDate(_date, date) ||
        _bowelAmountController.text.isNotEmpty ||
        !bowelMovement.isConfirmed) {
      return;
    }
    setState(() {
      _bowelAmountController.text =
          bowelMovement.status == BowelMovementStatus.none
          ? '0'
          : bowelMovement.amount?.toString() ?? '';
      _bowelShapeController.text = _shapeControllerValue(bowelMovement.shape);
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _shapeControllerValue(int? domainShape) {
    if (domainShape == null) return '';
    return (domainShape - 1).clamp(0, 2).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ACTIVITY')),
      body: switch (_mode) {
        _EntryMode.loading => const Center(child: CircularProgressIndicator()),
        _EntryMode.error => _LoadError(
          error: _loadError,
          onRetry: () =>
              _initializeForDate(_date, suppliedRecord: widget.initialData),
        ),
        _EntryMode.locked => _ConfirmedActivityLock(date: _date),
        _EntryMode.draft || _EntryMode.formal => _buildEntryBody(),
      },
    );
  }

  Widget _buildEntryBody() {
    final officialSteps = _officialSteps;
    return Padding(
      padding: AppSpacing.cardPadding,
      child: SingleChildScrollView(
        child: OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SectionHeader(
                    icon: Icons.directions_walk_outlined,
                    title: _isToday ? 'DAILY ACTIVITY' : 'PAST ACTIVITY',
                  ),
                ),
              ),
              if (!_isToday) ...[
                AppSpacing.gapSM,
                Semantics(
                  label: '${_formatDate(_date)}のActivity入力',
                  child: Text(
                    '${_formatDate(_date)} のActivity入力',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
              if (_hasDraftConflict) ...[
                AppSpacing.gapMD,
                const MaterialBanner(
                  content: Text('同じ日付の未確定Draftがあります。正式Recordを優先して表示しています。'),
                  actions: [SizedBox.shrink()],
                ),
              ],
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
              AppSpacing.gapMD,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [500, 1000, 2000, 5000]
                    .map(
                      (value) => OutlinedButton(
                        onPressed: _isBusy ? null : () => _addQuickSteps(value),
                        child: Text('+$value'),
                      ),
                    )
                    .toList(),
              ),
              AppSpacing.gapLG,
              if (_usesDigestiveEvents)
                _buildDigestiveEvents()
              else
                BowelCard(
                  amountController: _bowelAmountController,
                  shapeController: _bowelShapeController,
                ),
              AppSpacing.gapLG,
              if (_isFormal)
                OperationButton(
                  icon: Icons.save_outlined,
                  text: 'Save Activity',
                  onPressed: _isBusy ? null : _saveExisting,
                )
              else ...[
                Semantics(
                  label: '一時保存',
                  button: true,
                  child: OperationButton(
                    icon: Icons.save_outlined,
                    text: '一時保存',
                    onPressed: _isBusy ? null : _saveDraft,
                  ),
                ),
                AppSpacing.gapMD,
                Semantics(
                  label: '${_formatDate(_date)}のActivity記録を確定',
                  button: true,
                  child: OperationButton(
                    icon: Icons.task_alt,
                    text: _isToday ? '本日の記録を確定' : 'この日の記録を確定',
                    onPressed: _isBusy ? null : _finalizeDraft,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDigestiveEvents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(icon: Icons.monitor_heart, title: 'DIGESTIVE'),
        if (_digestiveEvents.isEmpty) ...[
          AppSpacing.gapMD,
          Text('排便イベントはありません', style: Theme.of(context).textTheme.bodySmall),
        ],
        for (final event in _digestiveEvents) ...[
          AppSpacing.gapMD,
          DigestiveEventCard(
            event: event,
            enabled: !_isBusy,
            onChanged: _updateDigestiveEvent,
            onDelete: () => _confirmDeleteDigestiveEvent(event),
          ),
        ],
        AppSpacing.gapMD,
        Semantics(
          label: '排便を追加',
          button: true,
          child: OutlinedButton.icon(
            key: const ValueKey('add-digestive-event'),
            onPressed: _isBusy ? null : _addDigestiveEvent,
            icon: const Icon(Icons.add),
            label: const Text('排便を追加'),
          ),
        ),
      ],
    );
  }

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _ConfirmedActivityLock extends StatelessWidget {
  final DateTime date;

  const _ConfirmedActivityLock({required this.date});

  @override
  Widget build(BuildContext context) {
    final localDate =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return Center(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: OperationCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 36),
              AppSpacing.gapMD,
              const Text(
                'この日のログは確定済みです。\n変更する場合は訂正処理を開始してください。',
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapSM,
              Text(localDate),
              AppSpacing.gapMD,
              OperationButton(
                text: 'BACK TO DASHBOARD',
                icon: Icons.arrow_back,
                onPressed: () => Navigator.popUntil(
                  context,
                  ModalRoute.withName(AppRoutes.dashboard),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _LoadError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Activity入力データを読み込めませんでした'),
            AppSpacing.gapSM,
            Text(
              error?.toString() ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            AppSpacing.gapMD,
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }
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
