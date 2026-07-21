import 'package:flutter/material.dart';

import '../../core/models/training_exercise.dart';
import '../../core/models/training_session.dart';
import '../../core/models/training_set.dart';
import '../../core/models/cardio_entry.dart';
import '../../core/repositories/training_repository.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../../core/theme/app_spacing.dart';

import '../morning/models/morning_fact.dart';
import '../morning/models/morning_fact_state.dart';
import 'models/training_exercise_controller.dart';
import 'models/training_session_controller.dart';
import 'models/training_set_controller.dart';
import 'models/training_summary_state.dart';

import 'widgets/training_exercise_list.dart';
import 'widgets/training_session_card.dart';
import 'widgets/training_submit_button.dart';
import '../../core/widgets/operation_menu_button.dart';
import 'training_plan_page.dart';

class TrainingEntryPage extends StatefulWidget {
  const TrainingEntryPage({super.key, this.existingSession});

  final TrainingSession? existingSession;

  @override
  State<TrainingEntryPage> createState() => _TrainingEntryPageState();
}

class _TrainingEntryPageState extends State<TrainingEntryPage> {
  final sessionController = TrainingSessionController();
  final List<_CardioPlaceholder> _cardioPlaceholders = [];
  int _nextCardioPlaceholderId = 0;

  bool isEditMode = false;

  bool get _isEditingExistingSession => widget.existingSession != null;

  @override
  void initState() {
    super.initState();
    _preloadExistingSession();
  }

  void _preloadExistingSession() {
    final session = widget.existingSession;
    if (session == null) {
      return;
    }

    sessionController.memoController.text = session.memo;
    sessionController.clearExercises();

    for (final exercise in session.exercises) {
      final controller = TrainingExerciseController(
        exerciseController: TextEditingController(text: exercise.exerciseName),
        sets: exercise.sets
            .map(
              (set) => TrainingSetController(
                weightController: TextEditingController(
                  text: set.weight.toString(),
                ),
                repsController: TextEditingController(
                  text: set.reps.toString(),
                ),
              ),
            )
            .toList(growable: false),
      );
      sessionController.exercises.add(controller);
    }

    for (final entry in session.cardioEntries) {
      final cardio = _CardioPlaceholder(_nextCardioPlaceholderId++)
        ..type = entry.type
        ..intensity = entry.intensity
        ..durationController.text = entry.durationMinutes.toString()
        ..distanceController.text = entry.distanceKm?.toString() ?? ''
        ..notesController.text = entry.notes ?? '';
      _cardioPlaceholders.add(cardio);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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

  Future<void> _save() async {
    var hasInvalidCardio = false;
    setState(() {
      for (final cardio in _cardioPlaceholders) {
        final duration = cardio.durationController.text.trim();
        final distance = cardio.distanceController.text.trim();
        final parsedDuration = int.tryParse(duration);
        final parsedDistance = distance.isEmpty ? null : double.tryParse(distance);
        cardio.durationError = parsedDuration == null || parsedDuration <= 0
            ? '運動時間は1分以上の整数で入力してください。'
            : null;
        cardio.distanceError = !distance.isEmpty &&
                (parsedDistance == null ||
                    !parsedDistance.isFinite ||
                    parsedDistance < 0)
            ? '距離は0以上の数値で入力してください。'
            : null;
        hasInvalidCardio |= cardio.durationError != null || cardio.distanceError != null;
      }
    });
    if (hasInvalidCardio) return;

    final exercises = <TrainingExercise>[];

    for (
      int exerciseIndex = 0;
      exerciseIndex < sessionController.exercises.length;
      exerciseIndex++
    ) {
      final controller = sessionController.exercises[exerciseIndex];
      final isUntouchedExercise =
          controller.exerciseController.text.trim().isEmpty &&
          controller.sets.every(
            (set) =>
                set.weightController.text.trim().isEmpty &&
                set.repsController.text.trim().isEmpty,
          );
      if (isUntouchedExercise) {
        continue;
      }

      if (controller.exerciseController.text.trim().isEmpty) {
        _showError('種目を入力してください');
        return;
      }

      final sets = <TrainingSet>[];

      for (int i = 0; i < controller.sets.length; i++) {
        final set = controller.sets[i];

        final weight = double.tryParse(set.weightController.text.trim());

        final reps = int.tryParse(set.repsController.text.trim());

        if (weight == null) {
          _showError('重量を入力してください');
          return;
        }

        if (reps == null) {
          _showError('回数を入力してください');
          return;
        }

        sets.add(TrainingSet(setNo: i + 1, weight: weight, reps: reps));
      }

      exercises.add(
        TrainingExercise(
          exerciseName: controller.exerciseController.text.trim(),
          order: exerciseIndex + 1,
          sets: sets,
        ),
      );
    }

    final morningFact = morningFactNotifier.value;
    final bodyWeightKg = morningFact != null && morningFact.weight > 0
        ? morningFact.weight
        : null;
    final cardioEntries = _cardioPlaceholders
        .map(
          (cardio) {
            final durationMinutes = int.parse(
              cardio.durationController.text.trim(),
            );
            final distanceText = cardio.distanceController.text.trim();
            final distanceKm = distanceText.isEmpty
                ? null
                : double.parse(distanceText);
            final estimatedCalories = bodyWeightKg == null
                ? null
                : estimateCardioCalories(
                    type: cardio.type,
                    intensity: cardio.intensity,
                    durationMinutes: durationMinutes,
                    bodyWeightKg: bodyWeightKg,
                  );

            return CardioEntry(
              type: cardio.type,
              intensity: cardio.intensity,
              durationMinutes: durationMinutes,
              distanceKm: distanceKm,
              notes: cardio.notesController.text,
              estimatedCalories: estimatedCalories,
            );
          },
        )
        .toList(growable: false);

    if (exercises.isEmpty && cardioEntries.isEmpty) {
      _showError('Add a strength exercise or cardio entry.');
      return;
    }

    final session = TrainingSession(
      date:
          widget.existingSession?.date ?? DateTime.now().toIso8601String(),
      memo: sessionController.memoController.text.trim(),
      exercises: exercises,
      cardioEntries: cardioEntries,
    );

    try {
      await DailyLogMutationGuard.assertDateMutable(
        DateTime.parse(session.date),
      );
      if (_isEditingExistingSession) {
        await TrainingRepository.replaceForLocalDate(session);
      } else {
        await TrainingRepository.save(session);
      }
    } on ConfirmedDailyLogException catch (error) {
      if (mounted) {
        showConfirmedLogMessage(context, error);
      }
      return;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save training. Please try again.'),
          ),
        );
      }
      return;
    }
    await refreshTrainingSummary();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          _isEditingExistingSession ? 'Training Updated' : 'Training Saved',
        ),
      ),
    );

    if (_isEditingExistingSession) {
      Navigator.pop(context, true);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    for (final cardio in _cardioPlaceholders) {
      cardio.dispose();
    }
    sessionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditingExistingSession ? 'Edit Training' : 'Training Entry',
        ),
        actions: [
          OperationMenuButton(
            items: [
              OperationMenuItem(
                icon: isEditMode ? Icons.check : Icons.edit_outlined,
                title: isEditMode ? 'Finish Editing' : 'Edit Mode',
                onTap: () {
                  setState(() {
                    isEditMode = !isEditMode;
                  });
                },
              ),

              OperationMenuItem(
                icon: Icons.delete_sweep_outlined,
                title: 'Clear Session',
                onTap: () {
                  setState(() {
                    sessionController.clearSession();
                  });
                },
              ),
              OperationMenuItem(
                icon: Icons.library_books_outlined,
                title: 'Training Plan',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrainingPlanPage(
                        onSelect: (exerciseNames) {
                          setState(() {
                            sessionController.clearExercises();

                            for (final name in exerciseNames) {
                              sessionController.addExerciseWithName(name);
                            }
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: AppSpacing.cardPadding,
        child: ValueListenableBuilder<MorningFact?>(
          valueListenable: morningFactNotifier,
          builder: (context, morningFact, child) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TrainingSessionCard(
                memoController: sessionController.memoController,
              ),

              AppSpacing.gapMD,

              TrainingExerciseList(
                exercises: sessionController.exercises,
                isEditMode: isEditMode,

                onCopy: (exercise) {
                  setState(() {
                    sessionController.addExerciseCopy(exercise);
                  });
                },

                onDelete: (exercise) {
                  setState(() {
                    sessionController.removeExercise(exercise);
                  });
                },
              ),

              AppSpacing.gapXL,

              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    sessionController.addExercise();
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Exercise'),
              ),

              AppSpacing.gapXL,

              const Text('Cardio', style: TextStyle(fontWeight: FontWeight.bold)),

              AppSpacing.gapMD,

              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _cardioPlaceholders.add(
                      _CardioPlaceholder(_nextCardioPlaceholderId++),
                    );
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Cardio'),
              ),

              AppSpacing.gapMD,

              for (
                var index = 0;
                index < _cardioPlaceholders.length;
                index++
              )
                Card(
                  key: ValueKey(_cardioPlaceholders[index].id),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Cardio ${index + 1}'),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                              ),
                              onPressed: () {
                                final cardio =
                                    _cardioPlaceholders.removeAt(index);

                                cardio.dispose();

                                setState(() {});
                              },
                            ),
                          ],
                        ),
                        DropdownButtonFormField<CardioType>(
                          value: _cardioPlaceholders[index].type,
                          decoration: const InputDecoration(
                            labelText: '種目',
                          ),
                          items: CardioType.values
                              .map(
                                (type) => DropdownMenuItem<CardioType>(
                                  value: type,
                                  child: Text(
                                    _cardioTypeLabel(type),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _cardioPlaceholders[index].type = value;
                            });
                          },
                        ),
                        DropdownButtonFormField<CardioIntensity>(
                          value: _cardioPlaceholders[index].intensity,
                          decoration: const InputDecoration(
                            labelText: '強度',
                          ),
                          items: CardioIntensity.values
                              .map(
                                (intensity) =>
                                    DropdownMenuItem<CardioIntensity>(
                                  value: intensity,
                                  child: Text(
                                    _cardioIntensityLabel(intensity),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _cardioPlaceholders[index].intensity = value;
                            });
                          },
                        ),
                        TextField(
                          controller:
                              _cardioPlaceholders[index].durationController,
                          decoration: InputDecoration(
                            labelText: '運動時間（分）',
                            errorText:
                                _cardioPlaceholders[index].durationError,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) {
                            setState(() {});
                          },
                        ),
                        TextField(
                          controller:
                              _cardioPlaceholders[index].distanceController,
                          decoration: InputDecoration(
                            labelText: '距離（km）',
                            errorText:
                                _cardioPlaceholders[index].distanceError,
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        TextField(
                          controller:
                              _cardioPlaceholders[index].notesController,
                          decoration: const InputDecoration(
                            labelText: 'メモ',
                          ),
                          minLines: 2,
                          maxLines: 3,
                        ),
                        AppSpacing.gapSM,
                        _buildCardioCaloriePreview(
                          morningFact,
                          _cardioPlaceholders[index],
                        ),
                      ],
                    ),
                  ),
                ),

              AppSpacing.gapXL,

              TrainingSubmitButton(onPressed: _save),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildCardioCaloriePreview(
    MorningFact? morningFact,
    _CardioPlaceholder cardio,
  ) {
    if (morningFact == null || morningFact.weight <= 0) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('推定消費カロリーを算出できません。'),
          Text('Morningの体重入力が必要です。'),
        ],
      );
    }

    final duration = int.tryParse(cardio.durationController.text.trim());
    if (duration == null || duration <= 0) {
      return const SizedBox.shrink();
    }

    final calories = estimateCardioCalories(
      type: cardio.type,
      intensity: cardio.intensity,
      durationMinutes: duration,
      bodyWeightKg: morningFact.weight,
    );

    return Text('推定消費カロリー：${calories.round()} kcal');
  }
}

String _cardioTypeLabel(CardioType type) => switch (type) {
  CardioType.walking => 'ウォーキング',
  CardioType.running => 'ランニング',
  CardioType.exerciseBike => 'エアロバイク',
  CardioType.elliptical => 'エリプティカル／クロストレーナー',
  CardioType.treadmillWalking => 'トレッドミル・ウォーキング',
  CardioType.treadmillRunning => 'トレッドミル・ランニング',
};

String _cardioIntensityLabel(CardioIntensity intensity) => switch (intensity) {
  CardioIntensity.light => '軽い',
  CardioIntensity.moderate => '普通',
  CardioIntensity.vigorous => '高い',
};
class _CardioPlaceholder { _CardioPlaceholder(this.id); final int id; final durationController = TextEditingController(); final distanceController = TextEditingController(); final notesController = TextEditingController(); String? durationError; String? distanceError; CardioType type = CardioType.exerciseBike; CardioIntensity intensity = CardioIntensity.moderate; void dispose() { durationController.dispose(); distanceController.dispose(); notesController.dispose(); } }
