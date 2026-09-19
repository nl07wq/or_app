import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/repositories/training_repository.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_card.dart';
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
import '../training_analysis/pages/training_analysis_page.dart';
import 'training_plan_page.dart';
import 'widgets/training_cardio_v2_editor.dart';
import 'widgets/training_dot_matrix_title.dart';
import 'widgets/training_led_back_button.dart';
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
  TrainingStatusWeightResolution? _statusWeight;
  String? _operationLocalDate;
  Object? _dateLoadError;
  bool _isLoadingDate = false;
  late final Future<ActiveTrainingDraftRepository?> _draftRepository;
  Future<void> _draftWriteQueue = Future.value();
  bool _draftWritesEnabled = true;
  bool _hasPersistedDraft = false;
  bool _confirmationOpen = false;

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
        _hasPersistedDraft = true;
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
      final weight = await TrainingStatusWeightResolver().resolveWithSource(
        localDate,
      );
      if (!mounted) return;
      setState(() => _statusWeight = weight);
    } catch (_) {
      // Missing STATUS remains an explicit uncomputed Cardio state.
    }
  }

  Future<void> _save() async {
    if (_isSaving || _hasSaved) return;
    setState(() => _isSaving = true);
    var saved = false;
    final previousEnd = _form.endTime;
    final previousPaused = _form.isPaused;
    TrainingRecord? savedRecord;
    try {
      if (!_isEditing && _form.startTime != null && _form.endTime == null) {
        _form.completeTraining(DateTime.now());
      }
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
        savedRecord = readBack;
      } else {
        await DailyLogMutationGuard.assertDateMutable(
          DateTime.parse(session.date),
        );
        savedRecord = await TrainingRepository.saveNewV2(session);
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
      _form.restoreDraftTimes(startTime: _form.startTime, endTime: previousEnd);
      _form.isPaused = previousPaused;
      _showError(error.message);
    } on ConfirmedDailyLogException catch (error) {
      _form.restoreDraftTimes(startTime: _form.startTime, endTime: previousEnd);
      _form.isPaused = previousPaused;
      if (mounted) showConfirmedLogMessage(context, error);
    } catch (_) {
      _form.restoreDraftTimes(startTime: _form.startTime, endTime: previousEnd);
      _form.isPaused = previousPaused;
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
    final createReport = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('TRAINING REPORT'),
        content: const Text('TRAINING REPORTを作成しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('YES'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (createReport == true && savedRecord != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TrainingAnalysisPage(targetRecordId: savedRecord!.id),
        ),
      );
      if (!mounted) return;
    }
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
    final previousPaused = _form.isPaused;
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
      _hasPersistedDraft = true;
      if (mounted) setState(() {});
    } on TrainingTimeValidationException catch (error) {
      _form.restoreDraftTimes(startTime: previousStart, endTime: previousEnd);
      _form.isPaused = previousPaused;
      if (mounted) _showTimeError(error.message);
    } catch (_) {
      _form.restoreDraftTimes(startTime: previousStart, endTime: previousEnd);
      _form.isPaused = previousPaused;
      if (mounted) {
        _showTimeError('Training Sessionの時刻を保存できませんでした。');
      }
    }
  }

  void _handleEntryChanged() {
    if (mounted) setState(() {});
    if (_isEditing ||
        (_form.startTime == null && !_hasPersistedDraft) ||
        !_draftWritesEnabled) {
      return;
    }
    unawaited(
      _persistDraftSnapshot().catchError((_) {
        if (mounted) _showTimeError('Training Sessionの入力内容を保存できませんでした。');
      }),
    );
  }

  Future<void> _confirmDeleteExercise(
    TrainingV2ExerciseFormController exercise,
  ) async {
    final confirmed = await _showTrainingConfirmation(
      title: 'この種目を削除しますか？',
      content: 'この種目と入力中のセットを削除します。\n\nこの操作は取り消せません。',
      confirmKey: const ValueKey('confirm-delete-exercise'),
    );
    if (confirmed != true || !_form.exercises.contains(exercise)) return;
    if (identical(_expandedItem, exercise)) _expandedItem = null;
    _form.removeExercise(exercise);
    _handleEntryChanged();
  }

  Future<void> _confirmDeleteCardio(
    TrainingV2CardioFormController cardio,
  ) async {
    final confirmed = await _showTrainingConfirmation(
      title: 'この有酸素運動を削除しますか？',
      content: 'この有酸素運動の入力内容を削除します。\n\nこの操作は取り消せません。',
      confirmKey: const ValueKey('confirm-delete-cardio'),
    );
    if (confirmed != true || !_form.cardioEntries.contains(cardio)) return;
    if (identical(_expandedItem, cardio)) _expandedItem = null;
    _form.removeCardio(cardio);
    _handleEntryChanged();
  }

  Future<void> _persistDraftSnapshot() {
    final start = _form.startTime;
    if ((start == null && !_hasPersistedDraft) || !_draftWritesEnabled) {
      return Future.value();
    }
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
    _statusWeight = null;
    _hasPersistedDraft = false;
    setState(() {});
    _loadStatusWeight();
  }

  Future<bool> _showTrainingConfirmation({
    required String title,
    required String content,
    required Key confirmKey,
    String confirmLabel = '削除',
  }) async {
    if (mounted) setState(() => _confirmationOpen = true);
    try {
      return (await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  key: confirmKey,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(dialogContext).colorScheme.error,
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(confirmLabel),
                ),
              ],
            ),
          )) ??
          false;
    } finally {
      if (mounted) setState(() => _confirmationOpen = false);
    }
  }

  Future<void> _discardOrClearSession() async {
    final confirmed = await _showTrainingConfirmation(
      title: 'トレーニングセッションを破棄しますか？',
      content: '現在のトレーニングセッションを破棄します。入力した内容はすべて失われます。',
      confirmKey: const ValueKey('confirm-discard-training'),
      confirmLabel: '破棄',
    );
    if (confirmed != true || !mounted) return;
    if (_isEditing || (_form.startTime == null && !_hasPersistedDraft)) {
      _resetSession();
      return;
    }
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
        appBar: AppBar(
          leading: Navigator.canPop(context)
              ? const TrainingLedBackButton()
              : null,
          title: const TrainingDotMatrixTitle(),
        ),
        body: const Center(child: Text('Operation Dateを取得できませんでした。')),
      );
    }
    final active = !_isEditing && _form.startTime != null;
    final presentationState = trainingPresentationState(
      startTime: _form.startTime,
      endTime: _form.endTime,
      isPaused: _form.isPaused,
      isEditing: _isEditing,
    );
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? TrainingLedBackButton(
                activeColor: switch (presentationState) {
                  TrainingPresentationState.active => AppColors.success,
                  TrainingPresentationState.paused => AppColors.warning,
                  _ => AppColors.primary,
                },
              )
            : null,
        // The title is deliberately in the full-width flexible space instead
        // of AppBar.title.  AppBar lays its title out between leading and
        // trailing controls, which shifts it when the recording badge is
        // present.  This overlay keeps the title locked to the viewport
        // center while leaving the controls independently tappable.
        flexibleSpace: SafeArea(
          bottom: false,
          child: IgnorePointer(
            child: Center(
              child: _TrainingAppBarTitle(
                state: presentationState,
                animateArrival:
                    presentationState == TrainingPresentationState.active &&
                    !_confirmationOpen,
              ),
            ),
          ),
        ),
        actions: [
          if (presentationState == TrainingPresentationState.active ||
              presentationState == TrainingPresentationState.paused)
            _TrainingAppBarStateBadge(state: presentationState),
          OperationMenuButton(
            items: [
              OperationMenuItem(
                icon: Icons.delete_sweep_outlined,
                title: 'DISCARD SESSION',
                onTap: () => unawaited(_discardOrClearSession()),
              ),
              OperationMenuItem(
                icon: Icons.library_books_outlined,
                title: 'TRAINING PLAN',
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
              key: ValueKey(switch (presentationState) {
                TrainingPresentationState.active => 'training-green-base',
                TrainingPresentationState.paused => 'training-amber-base',
                _ => 'training-blue-base',
              }),
              data: _trainingEntryTheme(context, state: presentationState),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_form.hasPlan) ...[
                    Theme(
                      data: Theme.of(context),
                      child: OperationCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(
                              icon: Icons.event_note_outlined,
                              title: 'PLAN READY',
                            ),
                            if (_form.planSourceOperationDate != null) ...[
                              AppSpacing.gapSM,
                              Text(
                                'REFERENCE  ${_form.planSourceOperationDate}',
                                key: const ValueKey(
                                  'active-training-plan-reference',
                                ),
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ],
                            if (_form.planNote != null) ...[
                              AppSpacing.gapSM,
                              Text(_form.planNote!),
                            ],
                          ],
                        ),
                      ),
                    ),
                    AppSpacing.gapMD,
                  ],
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
                  AppSpacing.gapMD,
                  const SectionHeader(
                    icon: Icons.fitness_center,
                    title: 'EXERCISE',
                  ),
                  AppSpacing.gapMD,
                  for (final (index, exercise) in _form.exercises.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: TrainingExerciseV2Editor(
                        index: index,
                        controller: exercise,
                        preferredRecords: _preferredRecords,
                        targetRecord: widget.existingRecord,
                        sessionDate: _form.date,
                        expanded: identical(_expandedItem, exercise),
                        onToggle: () => _toggle(exercise),
                        onDelete: () => _confirmDeleteExercise(exercise),
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
                  AppSpacing.gapMD,
                  const SectionHeader(
                    icon: Icons.directions_run,
                    title: 'CARDIO',
                  ),
                  AppSpacing.gapMD,
                  for (final (index, cardio) in _form.cardioEntries.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: TrainingCardioV2Editor(
                        index: index,
                        controller: cardio,
                        expanded: identical(_expandedItem, cardio),
                        calorieResult: _cardioPreview(cardio),
                        onToggle: () => _toggle(cardio),
                        onDelete: () => _confirmDeleteCardio(cardio),
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
                  AppSpacing.gapMD,
                  SizedBox(
                    height: 48,
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
      weightKg: cardio.weightSnapshotKg ?? _statusWeight?.weightKg,
    );
  }
}

class _TrainingAppBarTitle extends StatefulWidget {
  const _TrainingAppBarTitle({
    required this.state,
    required this.animateArrival,
  });

  final TrainingPresentationState state;
  final bool animateArrival;

  @override
  State<_TrainingAppBarTitle> createState() => _TrainingAppBarTitleState();
}

class _TrainingAppBarTitleState extends State<_TrainingAppBarTitle>
    with SingleTickerProviderStateMixin {
  static const _word = 'TRAINING';
  static const _characterTravel = Duration(milliseconds: 420);
  static const _characterSettle = Duration(milliseconds: 120);
  static const _fullWordHold = Duration(milliseconds: 900);

  late final AnimationController _controller;
  bool? _animationEnabled;
  List<double> get _slotOffsets =>
      List<double>.generate(_word.length, TrainingDotMatrixGeometry.glyphLeft);

  double get _internalTravelStart =>
      TrainingDotMatrixGeometry.panelWidth -
      TrainingDotMatrixGeometry.activeStagingRightInset -
      TrainingDotMatrixGeometry.glyphWidth;

  Duration get _cycleDuration => Duration(
    milliseconds:
        (_characterTravel.inMilliseconds + _characterSettle.inMilliseconds) *
            _word.length +
        _fullWordHold.inMilliseconds,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycleDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _TrainingAppBarTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animateArrival != widget.animateArrival) _syncAnimation();
  }

  void _syncAnimation() {
    final enabled =
        widget.animateArrival &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (_animationEnabled == enabled) return;
    _animationEnabled = enabled;
    _controller
      ..stop()
      ..reset();
    if (enabled) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _TrainingTitleFrame _frameFor(double value) {
    final elapsed = value * _cycleDuration.inMilliseconds;
    final phaseDuration =
        _characterTravel.inMilliseconds + _characterSettle.inMilliseconds;
    final phase = elapsed ~/ phaseDuration;
    if (phase >= _word.length) {
      return const _TrainingTitleFrame(settledCount: _word.length);
    }
    final phaseElapsed = elapsed - phase * phaseDuration;
    if (phaseElapsed >= _characterTravel.inMilliseconds) {
      return _TrainingTitleFrame(settledCount: phase + 1);
    }
    return _TrainingTitleFrame(
      settledCount: phase,
      travellingIndex: phase,
      travelProgress: phaseElapsed / _characterTravel.inMilliseconds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final staticTitle = !(_animationEnabled ?? false);
    final activeColor = switch (widget.state) {
      TrainingPresentationState.active => AppColors.success,
      TrainingPresentationState.paused => AppColors.warning,
      _ => AppColors.primary,
    };

    return Semantics(
      header: true,
      label: 'TRAINING',
      child: ExcludeSemantics(
        child: SizedBox(
          key: const ValueKey('training-appbar-title'),
          child: TrainingDotMatrixFrame(
            palette: TrainingDotMatrixPalette.fromActiveColor(activeColor),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (var index = 0; index < _word.length; index++)
                  Positioned(
                    key: ValueKey('training-title-slot-$index'),
                    left: _slotOffsets[index],
                    top: TrainingDotMatrixGeometry.verticalPadding,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0,
                        child: SizedBox(
                          width: TrainingDotMatrixGeometry.glyphWidth,
                          height: TrainingDotMatrixGeometry.glyphHeight,
                        ),
                      ),
                    ),
                  ),
                if (staticTitle)
                  for (var index = 0; index < _word.length; index++)
                    Positioned(
                      left: _slotOffsets[index],
                      top: TrainingDotMatrixGeometry.verticalPadding,
                      child: TrainingDotMatrixGlyph(
                        character: _word[index],
                        activeColor: activeColor,
                      ),
                    )
                else
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final frame = _frameFor(_controller.value);
                      final travelling = frame.travellingIndex;
                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          for (
                            var index = 0;
                            index < frame.settledCount;
                            index++
                          )
                            Positioned(
                              left: _slotOffsets[index],
                              top: TrainingDotMatrixGeometry.verticalPadding,
                              child: TrainingDotMatrixGlyph(
                                character: _word[index],
                                activeColor: activeColor,
                              ),
                            ),
                          if (frame.settledCount > 0)
                            Positioned(
                              key: ValueKey(
                                'training-title-settled-${frame.settledCount}',
                              ),
                              left: 0,
                              top: 0,
                              child: const SizedBox.shrink(),
                            ),
                          if (travelling != null)
                            Positioned(
                              key: ValueKey(
                                'training-title-travelling-$travelling',
                              ),
                              left: _travelLeft(
                                travelling,
                                frame.travelProgress,
                              ),
                              top: TrainingDotMatrixGeometry.verticalPadding,
                              child: TrainingDotMatrixGlyph(
                                character: _word[travelling],
                                activeColor: activeColor,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _travelLeft(int index, double progress) {
    final destination = _slotOffsets[index];
    // The right-side panel margin is the physical staging area.  Keeping the
    // start inside the local panel coordinate system prevents a glyph from
    // appearing to fly across the AppBar before it reaches the display.
    final start = _internalTravelStart;
    return start + (destination - start) * Curves.linear.transform(progress);
  }
}

class _TrainingTitleFrame {
  const _TrainingTitleFrame({
    required this.settledCount,
    this.travellingIndex,
    this.travelProgress = 0,
  });

  final int settledCount;
  final int? travellingIndex;
  final double travelProgress;
}

class _TrainingAppBarStateBadge extends StatelessWidget {
  const _TrainingAppBarStateBadge({required this.state});

  final TrainingPresentationState state;

  @override
  Widget build(BuildContext context) {
    final active = state == TrainingPresentationState.active;
    final color = active ? AppColors.success : AppColors.warning;
    final label = active ? 'ACTIVE' : 'PAUSED';
    return Semantics(
      label: 'Training session ${active ? 'active' : 'paused'}',
      child: Container(
        key: const ValueKey('training-appbar-state'),
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 7, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ThemeData _trainingEntryTheme(
  BuildContext context, {
  required TrainingPresentationState state,
}) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  final stateTint =
      state == TrainingPresentationState.active ||
      state == TrainingPresentationState.paused;
  final base = switch (state) {
    TrainingPresentationState.active => AppColors.success,
    TrainingPresentationState.paused => AppColors.warning,
    _ => AppColors.primary,
  };
  return theme.copyWith(
    cardColor: Color.alphaBlend(
      base.withValues(alpha: stateTint ? 0.12 : 0.07),
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
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      labelStyle: const TextStyle(fontSize: 12),
      floatingLabelStyle: const TextStyle(fontSize: 12),
    ),
    textTheme: theme.textTheme.copyWith(
      bodyLarge: theme.textTheme.bodyLarge?.copyWith(fontSize: 14),
    ),
  );
}
