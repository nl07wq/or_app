import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/repositories/training_repository.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_menu_button.dart';
import '../../core/widgets/section_header.dart';
import '../../data/indexed_db/indexed_db_database.dart';
import 'models/active_training_draft.dart';
import 'models/training_record_read_model.dart';
import 'models/training_summary_state.dart';
import 'models/training_v2_form_controller.dart';
import 'repository/active_training_draft_repository.dart';
import 'repository/indexed_db_active_training_draft_repository.dart';
import 'services/training_cardio_calorie_calculator.dart';
import 'services/training_status_weight_resolver.dart';
import 'services/training_v2_form_mapper.dart';
import '../operation_date/services/operation_date_service.dart';
import 'training_plan_page.dart';
import 'widgets/training_cardio_v2_editor.dart';
import 'widgets/training_exercise_v2_editor.dart';
import 'widgets/training_session_v2_form.dart';

class TrainingEntryPage extends StatefulWidget {
  final TrainingRecordReadModel? existingRecord;
  final ActiveTrainingDraftRepository? activeTrainingDraftRepository;

  const TrainingEntryPage({
    super.key,
    this.existingRecord,
    this.activeTrainingDraftRepository,
  });

  @override
  State<TrainingEntryPage> createState() => _TrainingEntryPageState();
}

class _TrainingEntryPageState extends State<TrainingEntryPage> {
  late TrainingV2FormController _form;
  List<TrainingRecordReadModel> _preferredRecords = const [];
  Object? _expandedItem;
  bool _isSaving = false;
  bool _hasSaved = false;
  double? _statusWeightKg;
  String? _operationLocalDate;
  Object? _dateLoadError;
  bool _isLoadingDate = false;
  late final Future<ActiveTrainingDraftRepository?> _draftRepository;
  Future<void> _draftWriteQueue = Future.value();
  bool _draftWritesEnabled = true;

  bool get _isEditing => widget.existingRecord != null;

  @override
  void initState() {
    super.initState();
    _draftRepository = _createDraftRepository();
    final existing = widget.existingRecord;
    if (existing != null && (!existing.isEditable || existing.v2Data == null)) {
      throw StateError('This TRAINING record is read-only.');
    }
    _form = existing == null
        ? TrainingV2FormController.newSession(now: DateTime(1970))
        : TrainingV2FormController.fromSession(existing.v2Data!);
    if (existing == null) {
      _isLoadingDate = true;
      _initializeNewSession();
    } else {
      _loadTrainingContext();
      _loadStatusWeight();
    }
  }

  Future<ActiveTrainingDraftRepository?> _createDraftRepository() async {
    final injected = widget.activeTrainingDraftRepository;
    if (injected != null) return injected;
    if (!kIsWeb) return null;
    return IndexedDbActiveTrainingDraftRepository(
      await openIndexedDbDatabase(),
    );
  }

  Future<void> _initializeNewSession() async {
    try {
      final localDate = (await const OperationDateService().current()).value;
      if (!mounted) return;
      _form.dispose();
      _form = TrainingV2FormController.newSession(localDate: localDate);
      final draft = await (await _draftRepository)?.findByOperationDate(
        localDate,
      );
      if (!mounted) return;
      if (draft != null) {
        _form.restoreDraftTimes(
          startTime: draft.startTime,
          endTime: draft.endTime,
        );
        final entryState = draft.entryState;
        if (entryState != null) _form.restoreDraftState(entryState);
      }
      _operationLocalDate = localDate;
      _expandedItem = _form.exercises.first;
      setState(() => _isLoadingDate = false);
      _loadTrainingContext();
      _loadStatusWeight();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _dateLoadError = error;
        _isLoadingDate = false;
      });
    }
  }

  Future<void> _loadTrainingContext() async {
    try {
      final records = await TrainingRepository.getReadModels();
      if (!mounted) return;
      setState(() {
        _preferredRecords = List.unmodifiable(records);
      });
    } catch (_) {
      // Built-in candidates remain available; persistence errors surface on save.
    }
  }

  Future<void> _loadStatusWeight() async {
    try {
      final localDate = _form.date.substring(0, 10);
      final weight = await TrainingStatusWeightResolver().resolve(localDate);
      if (!mounted) return;
      setState(() => _statusWeightKg = weight);
    } catch (_) {
      // Missing STATUS remains an explicit uncomputed Cardio state.
    }
  }

  Future<void> _save() async {
    if (_isSaving || _hasSaved) return;
    setState(() => _isSaving = true);
    var saved = false;
    try {
      final session = TrainingV2FormMapper.toDomain(_form);
      if (_isEditing) {
        final date = DateTime.parse(session.date);
        await DailyLogMutationGuard.assertDateMutable(date);
        final readBack = await TrainingRepository.updateV2ById(
          widget.existingRecord!.id,
          session,
        );
        if (readBack.id != widget.existingRecord!.id ||
            readBack.localDate != session.date.substring(0, 10)) {
          throw StateError('targetRecordReadBackFailed');
        }
      } else {
        await DailyLogMutationGuard.assertDateMutable(
          DateTime.parse(session.date),
        );
        await TrainingRepository.saveNewV2(session);
        _draftWritesEnabled = false;
        await _draftWriteQueue;
        await (await _draftRepository)?.deleteByOperationDate(
          session.date.substring(0, 10),
        );
      }
      await refreshTrainingSummary();
      _hasSaved = true;
      saved = true;
    } on TrainingV2FormValidationException catch (error) {
      _showError(error.message);
    } on ConfirmedDailyLogException catch (error) {
      if (mounted) showConfirmedLogMessage(context, error);
    } catch (_) {
      _draftWritesEnabled = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('トレーニングの保存に失敗しました。入力内容を維持しています。')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    if (!saved || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? 'TRAININGを更新しました' : 'TRAININGを保存しました'),
      ),
    );
    Navigator.pop(context, true);
  }

  Future<void> _startTraining() =>
      _updateActiveDraft(() => _form.startTraining(DateTime.now()));

  Future<void> _endTraining() =>
      _updateActiveDraft(() => _form.endTraining(DateTime.now()));

  Future<void> _undoEnd() => _updateActiveDraft(_form.undoEnd);

  Future<void> _editStartTime(TimeOfDay value) =>
      _updateActiveDraft(() => _form.editStartTime(value, now: DateTime.now()));

  Future<void> _editEndTime(TimeOfDay value) =>
      _updateActiveDraft(() => _form.editEndTime(value));

  Future<void> _updateActiveDraft(VoidCallback update) async {
    if (_isEditing) {
      update();
      if (mounted) setState(() {});
      return;
    }
    final previousStart = _form.startTime;
    final previousEnd = _form.endTime;
    try {
      update();
      final start = _form.startTime;
      if (start == null) {
        throw const TrainingTimeValidationException(
          'Active Training DraftにはStart Timeが必要です。',
        );
      }
      final operationDate = _form.date.substring(0, 10);
      await DailyLogMutationGuard.assertDateMutable(
        DateTime.parse(operationDate),
      );
      final repository = await _draftRepository;
      await _draftWriteQueue;
      await repository?.save(
        ActiveTrainingDraft(
          operationDate: operationDate,
          startTime: start,
          endTime: _form.endTime,
          entryState: _form.toDraftState(),
        ),
      );
      if (mounted) setState(() {});
    } on TrainingTimeValidationException catch (error) {
      _form.restoreDraftTimes(startTime: previousStart, endTime: previousEnd);
      if (mounted) _showTimeError(error.message);
    } catch (_) {
      _form.restoreDraftTimes(startTime: previousStart, endTime: previousEnd);
      if (mounted) {
        _showTimeError('Training Sessionの時刻を保存できませんでした。');
      }
    }
  }

  void _handleEntryChanged() {
    if (mounted) setState(() {});
    if (_isEditing || _form.startTime == null || !_draftWritesEnabled) return;
    unawaited(
      _persistDraftSnapshot().catchError((_) {
        if (mounted) _showTimeError('Training Sessionの入力内容を保存できませんでした。');
      }),
    );
  }

  Future<void> _persistDraftSnapshot() {
    final start = _form.startTime;
    if (start == null || !_draftWritesEnabled) return Future.value();
    final snapshot = ActiveTrainingDraft(
      operationDate: _form.date.substring(0, 10),
      startTime: start,
      endTime: _form.endTime,
      entryState: _form.toDraftState(),
    );
    final operation = _draftWriteQueue.then((_) async {
      final repository = await _draftRepository;
      await repository?.save(snapshot);
    });
    _draftWriteQueue = operation.catchError((_) {});
    return operation;
  }

  void _showTimeError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('入力エラー'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _replaceExercises(Iterable<String> names) {
    for (final exercise in _form.exercises) {
      exercise.dispose();
    }
    _form.exercises
      ..clear()
      ..addAll(
        names.map((name) {
          final value = TrainingV2ExerciseFormController();
          value.exerciseName.text = name;
          return value;
        }),
      );
    _expandedItem = _form.exercises.lastOrNull;
    _handleEntryChanged();
  }

  void _resetSession() {
    final localDate = _isEditing
        ? _form.date.substring(0, 10)
        : _operationLocalDate;
    _form.dispose();
    _form = TrainingV2FormController.newSession(localDate: localDate);
    _expandedItem = _form.exercises.first;
    _statusWeightKg = null;
    setState(() {});
    _loadStatusWeight();
  }

  Future<void> _discardOrClearSession() async {
    if (_isEditing || _form.startTime == null) {
      _resetSession();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DISCARD TRAINING?'),
        content: const Text('記録中のTraining Sessionと入力内容を破棄します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DISCARD'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final operationDate = _form.date.substring(0, 10);
    try {
      _draftWritesEnabled = false;
      await _draftWriteQueue;
      await (await _draftRepository)?.deleteByOperationDate(operationDate);
      if (!mounted) return;
      _resetSession();
      _draftWritesEnabled = true;
    } catch (_) {
      _draftWritesEnabled = true;
      if (mounted) _showTimeError('Training Sessionを破棄できませんでした。');
    }
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDate) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_dateLoadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('TRAINING')),
        body: const Center(child: Text('Operation Dateを取得できませんでした。')),
      );
    }
    final active = !_isEditing && _form.startTime != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('TRAINING'),
        actions: [
          OperationMenuButton(
            items: [
              OperationMenuItem(
                icon: Icons.delete_sweep_outlined,
                title: _form.startTime == null
                    ? 'Clear Session'
                    : 'Discard Session',
                onTap: () => unawaited(_discardOrClearSession()),
              ),
              OperationMenuItem(
                icon: Icons.library_books_outlined,
                title: 'Training Plan',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TrainingPlanPage(onSelect: _replaceExercises),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.cardPadding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Theme(
              key: ValueKey(
                active ? 'training-green-base' : 'training-blue-base',
              ),
              data: _trainingEntryTheme(context, active: active),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TrainingSessionV2Form(
                    controller: _form,
                    active: active,
                    onChanged: _handleEntryChanged,
                    onStartTraining: _startTraining,
                    onEndTraining: _endTraining,
                    onUndoEnd: _undoEnd,
                    onEditStartTime: _editStartTime,
                    onEditEndTime: _editEndTime,
                  ),
                  AppSpacing.gapXL,
                  const SectionHeader(
                    icon: Icons.fitness_center,
                    title: 'EXERCISE',
                  ),
                  AppSpacing.gapMD,
                  for (final (index, exercise) in _form.exercises.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: TrainingExerciseV2Editor(
                        index: index,
                        controller: exercise,
                        preferredRecords: _preferredRecords,
                        targetRecord: widget.existingRecord,
                        sessionDate: _form.date,
                        expanded: identical(_expandedItem, exercise),
                        onToggle: () => _toggle(exercise),
                        onDelete: () {
                          if (identical(_expandedItem, exercise)) {
                            _expandedItem = null;
                          }
                          _form.removeExercise(exercise);
                          _handleEntryChanged();
                        },
                        onChanged: _handleEntryChanged,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () {
                      _form.addExercise();
                      _expandedItem = _form.exercises.last;
                      _handleEntryChanged();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('ADD EXERCISE'),
                  ),
                  AppSpacing.gapXL,
                  const SectionHeader(
                    icon: Icons.directions_run,
                    title: 'CARDIO',
                  ),
                  AppSpacing.gapMD,
                  for (final (index, cardio) in _form.cardioEntries.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: TrainingCardioV2Editor(
                        index: index,
                        controller: cardio,
                        expanded: identical(_expandedItem, cardio),
                        calorieResult: _cardioPreview(cardio),
                        onToggle: () => _toggle(cardio),
                        onDelete: () {
                          if (identical(_expandedItem, cardio)) {
                            _expandedItem = null;
                          }
                          _form.removeCardio(cardio);
                          _handleEntryChanged();
                        },
                        onChanged: _handleEntryChanged,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () {
                      _form.addCardio();
                      _expandedItem = _form.cardioEntries.last;
                      _handleEntryChanged();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('ADD CARDIO'),
                  ),
                  AppSpacing.gapXL,
                  SizedBox(
                    height: 56,
                    child: OperationButton(
                      icon: Icons.save,
                      text: _isEditing ? 'UPDATE TRAINING' : 'SAVE TRAINING',
                      onPressed: _isSaving ? null : _save,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggle(Object value) {
    setState(() {
      _expandedItem = identical(_expandedItem, value) ? null : value;
    });
  }

  TrainingCardioCalorieResult _cardioPreview(
    TrainingV2CardioFormController cardio,
  ) {
    final duration = TrainingV2FormMapper.tryParseDurationSeconds(
      cardio.duration.text,
    );
    return TrainingCardioCalorieCalculator.calculate(
      mets: double.tryParse(cardio.mets.text.trim()),
      durationSeconds: duration,
      weightKg: cardio.weightSnapshotKg ?? _statusWeightKg,
    );
  }
}

ThemeData _trainingEntryTheme(BuildContext context, {required bool active}) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  final base = active ? AppColors.success : AppColors.primary;
  return theme.copyWith(
    cardColor: Color.alphaBlend(
      base.withValues(alpha: active ? 0.12 : 0.07),
      theme.cardColor,
    ),
    colorScheme: colors.copyWith(
      primary: base,
      primaryContainer: Color.alphaBlend(
        base.withValues(alpha: 0.20),
        colors.surface,
      ),
      onPrimaryContainer: colors.onSurface,
      outline: Color.alphaBlend(base.withValues(alpha: 0.65), colors.outline),
      outlineVariant: Color.alphaBlend(
        base.withValues(alpha: 0.42),
        colors.outlineVariant,
      ),
    ),
  );
}
