import 'package:flutter/material.dart';

import '../../core/repositories/training_repository.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../../core/widgets/operation_button.dart';
import '../../core/widgets/operation_menu_button.dart';
import '../../core/widgets/section_header.dart';
import 'models/training_record_read_model.dart';
import 'models/training_summary_state.dart';
import 'models/training_v2_form_controller.dart';
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

  const TrainingEntryPage({super.key, this.existingRecord});

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

  bool get _isEditing => widget.existingRecord != null;

  @override
  void initState() {
    super.initState();
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

  Future<void> _initializeNewSession() async {
    try {
      final localDate = (await const OperationDateService().current()).value;
      if (!mounted) return;
      _form.dispose();
      _form = TrainingV2FormController.newSession(localDate: localDate);
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
      await DailyLogMutationGuard.assertDateMutable(
        DateTime.parse(session.date),
      );
      if (_isEditing) {
        await TrainingRepository.updateV2ById(
          widget.existingRecord!.id,
          session,
        );
      } else {
        await TrainingRepository.saveNewV2(session);
      }
      await refreshTrainingSummary();
      _hasSaved = true;
      saved = true;
    } on TrainingV2FormValidationException catch (error) {
      _showError(error.message);
    } on ConfirmedDailyLogException catch (error) {
      if (mounted) showConfirmedLogMessage(context, error);
    } catch (_) {
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
    setState(() {});
  }

  void _clearSession() {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('TRAINING'),
        actions: [
          OperationMenuButton(
            items: [
              OperationMenuItem(
                icon: Icons.delete_sweep_outlined,
                title: 'Clear Session',
                onTap: _clearSession,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TrainingSessionV2Form(
                  controller: _form,
                  onChanged: () => setState(() {}),
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
                        setState(() {});
                      },
                      onChanged: () => setState(() {}),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () {
                    _form.addExercise();
                    _expandedItem = _form.exercises.last;
                    setState(() {});
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
                        setState(() {});
                      },
                      onChanged: () => setState(() {}),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () {
                    _form.addCardio();
                    _expandedItem = _form.cardioEntries.last;
                    setState(() {});
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
