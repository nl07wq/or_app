import 'dart:convert';

import '../../../core/data/default_training_templates.dart';
import '../../../core/models/training_equipment_snapshot.dart';
import '../../../core/models/training_exercise.dart';
import '../../../core/models/training_exercise_v2.dart';
import '../../../core/models/training_set_v2.dart';
import '../../report_sync/models/report_sync_envelope.dart';
import '../../report_sync/models/report_sync_issue.dart';
import '../../report_sync/services/report_sync_canonical_service.dart';
import '../../repositories/app_repository_container.dart';
import '../models/active_training_draft.dart';
import '../models/training_plan_proposal.dart';
import '../models/training_record_read_model.dart';
import '../repository/active_training_draft_repository.dart';
import '../repository/indexed_db_active_training_draft_repository.dart';
import 'equipment_catalog.dart';
import 'training_exercise_identity.dart';

class TrainingPlanPreparation {
  const TrainingPlanPreparation({
    required this.operationDate,
    required this.sourceDigest,
    required this.prompt,
  });

  final String operationDate;
  final String sourceDigest;
  final String prompt;
}

class TrainingPlanPreview {
  const TrainingPlanPreview({
    required this.response,
    required this.plan,
    required this.sourceDigest,
  });

  final ReportSyncEnvelope response;
  final TrainingPlanProposal plan;
  final String sourceDigest;
}

class TrainingPlanService {
  TrainingPlanService({
    AppRepositoryContainer? container,
    ActiveTrainingDraftRepository? draftRepository,
    DateTime Function()? clock,
  }) : _containerOverride = container,
       _draftRepositoryOverride = draftRepository,
       _clock = clock ?? DateTime.now;

  final AppRepositoryContainer? _containerOverride;
  final ActiveTrainingDraftRepository? _draftRepositoryOverride;
  final DateTime Function() _clock;

  AppRepositoryContainer get _container =>
      _containerOverride ?? AppRepositoryRegistry.container;

  ActiveTrainingDraftRepository get _draftRepository =>
      _draftRepositoryOverride ??
      IndexedDbActiveTrainingDraftRepository(_container.database);

  Future<TrainingPlanPreparation> prepare({String? targetRecordId}) async {
    final package = await _factPackage(targetRecordId: targetRecordId);
    final operationDate = package['operationDate']! as String;
    final latestTraining = package['latestTraining'] as Map?;
    final sourceRecordId = latestTraining?['recordId'] as String?;
    final sourceDigest = ReportSyncCanonicalService.digest(package);
    final timestamp = _clock().toUtc();
    final requestId =
        'training-plan-request:${timestamp.microsecondsSinceEpoch}-'
        '${sourceDigest.substring(0, 12)}';
    final payload = <String, Object?>{
      'operationDate': operationDate,
      'sourceRecordId': sourceRecordId,
      'sourceDigest': sourceDigest,
      'facts': package,
    };
    final request = _container.reportSyncCodec.create(
      direction: ReportSyncDirection.request,
      exchangeType: ReportSyncExchangeType.trainingPlan,
      exchangeId: requestId,
      requestId: requestId,
      operationDate: operationDate,
      createdAt: timestamp,
      requestDigest: ReportSyncCanonicalService.digest(payload),
      confirmationDigest: null,
      payload: payload,
    );
    await _container.reportSyncPersistence.recordRequest(request);
    return TrainingPlanPreparation(
      operationDate: operationDate,
      sourceDigest: sourceDigest,
      prompt: _prompt(request, sourceDigest),
    );
  }

  Future<TrainingPlanPreview> preview(String rawResponse) async {
    final response = _container.reportSyncCodec.decode(rawResponse.trim());
    if (response.direction != ReportSyncDirection.response ||
        response.exchangeType != ReportSyncExchangeType.trainingPlan ||
        response.schemaVersion != ReportSyncEnvelope.importSchemaVersion2) {
      throw const ReportSyncException(
        ReportSyncIssueCode.exchangeTypeMismatch,
        'TRAINING PLAN response required.',
      );
    }
    final expectedOperationDate =
        (await _container.operationState.requireCurrent()).operationDate.value;
    await _container.reportSyncValidator.validateResponse(
      response,
      expectedOperationDate: expectedOperationDate,
    );
    final sourceRecordId = response.payload['sourceRecordId'] as String?;
    final currentFacts = await _factPackage(targetRecordId: sourceRecordId);
    final expectedSourceRecordId =
        (currentFacts['latestTraining'] as Map?)?['recordId'] as String?;
    if (sourceRecordId != expectedSourceRecordId) {
      throw const ReportSyncException(
        ReportSyncIssueCode.integrityFailure,
        'Training Plan source identity changed.',
      );
    }
    final currentDigest = ReportSyncCanonicalService.digest(currentFacts);
    if (response.payload['sourceDigest'] != currentDigest) {
      throw const ReportSyncException(
        ReportSyncIssueCode.integrityFailure,
        'Training facts changed after Prompt generation.',
      );
    }
    final allowed = await _allowedExercises(
      await _container.training.findAllRecords(),
    );
    final rawPlan = Map<String, Object?>.from(response.payload['plan'] as Map);
    final exercises = <TrainingPlanExercise>[];
    for (final rawExercise in rawPlan['exercises'] as List) {
      final value = Map<String, Object?>.from(rawExercise as Map);
      final identity = value['exerciseIdentity']! as String;
      final source = allowed[identity];
      if (source == null || source.name != value['exerciseName']) {
        throw const ReportSyncException(
          ReportSyncIssueCode.integrityFailure,
          'Unknown Training Plan exercise identity.',
        );
      }
      final sets = <TrainingPlanSet>[];
      for (final rawSet in value['sets'] as List) {
        final set = Map<String, Object?>.from(rawSet as Map);
        sets.add(
          TrainingPlanSet(
            order: set['order']! as int,
            setType: TrainingSetType.fromStableId(set['setType']! as String),
            plannedWeightKg: (set['plannedWeightKg']! as num).toDouble(),
            targetMinReps: set['targetMinReps']! as int,
            targetMaxReps: set['targetMaxReps']! as int,
            restAfterSeconds: set['restAfterSeconds'] as int?,
          ),
        );
      }
      exercises.add(
        TrainingPlanExercise(
          identity: identity,
          name: source.name,
          equipment: source.equipment,
          sets: sets,
        ),
      );
    }
    return TrainingPlanPreview(
      response: response,
      sourceDigest: currentDigest,
      plan: TrainingPlanProposal(
        operationDate: response.operationDate,
        exercises: exercises,
        note: rawPlan['note'] as String?,
      ),
    );
  }

  Future<ActiveTrainingDraft> apply(TrainingPlanPreview preview) async {
    final sourceRecordId =
        preview.response.payload['sourceRecordId'] as String?;
    final currentFacts = await _factPackage(targetRecordId: sourceRecordId);
    if (ReportSyncCanonicalService.digest(currentFacts) !=
        preview.sourceDigest) {
      throw const ReportSyncException(
        ReportSyncIssueCode.integrityFailure,
        'Training facts changed after validation.',
      );
    }
    final existing = await _draftRepository.findByOperationDate(
      preview.plan.operationDate,
    );
    if (existing?.startTime != null) {
      throw const ReportSyncException(
        ReportSyncIssueCode.integrityFailure,
        'An active Training Session cannot be replaced by a plan.',
      );
    }
    final draft = ActiveTrainingDraft(
      operationDate: preview.plan.operationDate,
      entryState: _entryState(preview),
    );
    await _draftRepository.save(draft);
    return (await _draftRepository.findByOperationDate(
      preview.plan.operationDate,
    ))!;
  }

  Future<Map<String, Object?>> _factPackage({String? targetRecordId}) async {
    final state = await _container.operationState.requireCurrent();
    final records = (await _container.training.findAllRecords()).toList()
      ..sort((a, b) => b.sortDateTime.compareTo(a.sortDateTime));
    TrainingRecordReadModel? latest;
    if (targetRecordId != null) {
      latest = await _container.training.findRecordById(targetRecordId);
      if (latest == null) {
        throw const ReportSyncException(
          ReportSyncIssueCode.integrityFailure,
          'Target Training Record does not exist.',
        );
      }
    } else if (records.isNotEmpty) {
      latest = records.first;
    }
    final allowed = await _allowedExercises(records);
    final latestAnalysis = latest == null
        ? null
        : await _container.trainingAnalysisReports.read(latest.id);
    return {
      'operationDate': state.operationDate.value,
      'latestTraining': latest == null ? null : _recordFact(latest),
      'comparisons': latest == null
          ? <Object?>[]
          : [
              for (final exercise in _exerciseFacts(latest))
                {
                  'exerciseIdentity': exercise.identity,
                  'exerciseName': exercise.name,
                  'previous': _comparables(records, latest, exercise),
                },
            ],
      'latestAnalysis': latestAnalysis?.analysis.toJson(),
      'availableExercises': [
        for (final value in allowed.values)
          {
            'exerciseIdentity': value.identity,
            'exerciseName': value.name,
            'equipment': value.equipment?.toJson(),
          },
      ],
    };
  }

  Future<Map<String, _AllowedExercise>> _allowedExercises(
    List<TrainingRecordReadModel> records,
  ) async {
    final values = <String, _AllowedExercise>{};
    void add(String name, TrainingEquipmentSnapshot? equipment) {
      final exercise = TrainingExerciseV2(
        exerciseName: name,
        order: 1,
        equipment: equipment,
      );
      final identity = _identity(TrainingExerciseIdentity.v2(exercise));
      values.putIfAbsent(
        identity,
        () => _AllowedExercise(identity, name, equipment),
      );
    }

    for (final record in records) {
      if (record.v2Data != null) {
        for (final exercise in record.v2Data!.exercises) {
          add(exercise.exerciseName, exercise.equipment);
        }
      } else {
        for (final exercise in record.v1Data!.exercises) {
          final equipment = equipmentById(exercise.equipmentId);
          add(
            exercise.exerciseName,
            equipment == null
                ? null
                : TrainingEquipmentSnapshot(
                    catalogId: equipment.id,
                    name: equipment.displayName,
                  ),
          );
        }
      }
    }
    for (final template in defaultTrainingTemplates) {
      for (final name in template.exercises) {
        add(name, null);
      }
    }
    for (final custom in await _container.customTrainingExercises.findAll()) {
      add(custom.name, null);
    }
    return values;
  }

  List<Map<String, Object?>> _comparables(
    List<TrainingRecordReadModel> records,
    TrainingRecordReadModel target,
    _PlanExerciseFact current,
  ) {
    final result = <Map<String, Object?>>[];
    for (final record in records) {
      if (record.id == target.id ||
          !record.sortDateTime.isBefore(target.sortDateTime)) {
        continue;
      }
      for (final exercise in _exerciseFacts(record)) {
        if (exercise.identity != current.identity) continue;
        result.add({
          'recordId': record.id,
          'operationDate': record.localDate,
          'elapsedDays': DateTime.parse(
            target.localDate,
          ).difference(DateTime.parse(record.localDate)).inDays,
          'weightTrendKg': current.topWeightKg - exercise.topWeightKg,
          'repTrend': current.totalReps - exercise.totalReps,
          'setTrend': current.setCount - exercise.setCount,
          'volumeTrendKg': current.volumeKg - exercise.volumeKg,
          'fact': exercise.fact,
        });
        break;
      }
      if (result.length == 5) break;
    }
    return result;
  }

  List<_PlanExerciseFact> _exerciseFacts(TrainingRecordReadModel record) =>
      record.v2Data != null
      ? [
          for (final exercise in record.v2Data!.exercises)
            _PlanExerciseFact.v2(exercise),
        ]
      : [
          for (final exercise in record.v1Data!.exercises)
            _PlanExerciseFact.v1(exercise),
        ];

  Map<String, Object?> _recordFact(TrainingRecordReadModel record) => {
    'recordId': record.id,
    'recordVersion': record.recordVersion,
    'operationDate': record.localDate,
    'session': record.v2Data?.toJson() ?? record.v1Data!.toJson(),
  };

  Map<String, Object?> _entryState(TrainingPlanPreview preview) => {
    'sessionName': '',
    'sessionMemo': '',
    'overallEvaluation': '',
    'sessionGrade': null,
    'dynamicStretchCompleted': null,
    'cooldownStretchCompleted': null,
    'planMetadata': {
      'exchangeId': preview.response.exchangeId,
      'sourceDigest': preview.sourceDigest,
      'note': preview.plan.note,
    },
    'exercises': [
      for (final exercise in preview.plan.exercises)
        {
          'exerciseName': exercise.name,
          'equipment': exercise.equipment?.toJson(),
          'equipmentSelectionMade': true,
          'evaluation': '',
          'targetWeight': '',
          'targetReps': <String>[],
          'targetNotes': '',
          'sets': [
            for (final set in exercise.sets)
              {
                'setType': set.setType.stableId,
                'weight': '',
                'reps': '',
                'rpe': null,
                'rest': set.restAfterSeconds?.toString() ?? '',
                'plannedWeightKg': set.plannedWeightKg,
                'targetMinReps': set.targetMinReps,
                'targetMaxReps': set.targetMaxReps,
              },
          ],
        },
    ],
    'cardioEntries': <Object?>[],
  };

  String _prompt(ReportSyncEnvelope request, String sourceDigest) {
    final operationDate = request.operationDate;
    final example = {
      'format': ReportSyncEnvelope.formatId,
      'envelopeVersion': 1,
      'schemaVersion': ReportSyncEnvelope.importSchemaVersion2,
      'direction': ReportSyncDirection.response.stableId,
      'exchangeType': ReportSyncExchangeType.trainingPlan.stableId,
      'exchangeId': '<UNIQUE_RESPONSE_ID>',
      'operationDate': operationDate,
      'createdAt': '<UTC_TIMESTAMP>',
      'confirmationDigest': null,
      'payload': {
        'operationDate': operationDate,
        'sourceRecordId': request.payload['sourceRecordId'],
        'sourceDigest': sourceDigest,
        'plan': {
          'note': '<concise Japanese note or null>',
          'exercises': [
            {
              'exerciseIdentity': '<exact available identity>',
              'exerciseName': '<exact available name>',
              'sets': [
                {
                  'order': 1,
                  'setType': 'main',
                  'plannedWeightKg': 70,
                  'targetMinReps': 8,
                  'targetMaxReps': 10,
                  'restAfterSeconds': 90,
                },
              ],
            },
          ],
        },
      },
      'packageDigest': null,
    };
    return '''
Create the next Operation Reboot TRAINING PLAN from the exact fact package.

RESPONSIBILITY
Operation Reboot owns all Formal Training facts and comparisons. Return a proposal only. Do not modify facts, invent history, create an exercise identity, or create a Formal Training Record. Use only an exact exerciseIdentity and exerciseName from availableExercises. Preserve warmUp/main meaning. targetMinReps is the minimum and targetMaxReps is the upper target.

RESPONSE CONTRACT
Return exactly one fenced Plain Text code block using ```text. Put one JSON object inside and nothing outside it. Use schemaVersion "2.0", direction "response", exchangeType "trainingPlan", operationDate "$operationDate", and sourceDigest "$sourceDigest" exactly. Set packageDigest to null. Create a unique exchangeId and UTC createdAt. Do not add, remove, or rename fields.

COMPLETE RESPONSE SHAPE
${const JsonEncoder.withIndent('  ').convert(example)}

FORMAL FACT PACKAGE
${const JsonEncoder.withIndent('  ').convert(request.payload['facts'])}
'''
        .trim();
  }
}

class _AllowedExercise {
  const _AllowedExercise(this.identity, this.name, this.equipment);
  final String identity;
  final String name;
  final TrainingEquipmentSnapshot? equipment;
}

class _PlanExerciseFact {
  const _PlanExerciseFact({
    required this.identity,
    required this.name,
    required this.fact,
    required this.topWeightKg,
    required this.totalReps,
    required this.setCount,
    required this.volumeKg,
  });

  factory _PlanExerciseFact.v2(TrainingExerciseV2 exercise) =>
      _PlanExerciseFact._fromSets(
        identity: _identity(TrainingExerciseIdentity.v2(exercise)),
        name: exercise.exerciseName,
        fact: exercise.toJson(),
        weights: exercise.sets.map((set) => set.weightKg),
        reps: exercise.sets.map((set) => set.reps),
      );

  factory _PlanExerciseFact.v1(TrainingExercise exercise) =>
      _PlanExerciseFact._fromSets(
        identity: _identity(TrainingExerciseIdentity.v1(exercise)),
        name: exercise.exerciseName,
        fact: exercise.toJson(),
        weights: exercise.sets.map((set) => set.weight),
        reps: exercise.sets.map((set) => set.reps),
      );

  factory _PlanExerciseFact._fromSets({
    required String identity,
    required String name,
    required Map<String, Object?> fact,
    required Iterable<double> weights,
    required Iterable<int> reps,
  }) {
    final weightList = weights.toList();
    final repList = reps.toList();
    return _PlanExerciseFact(
      identity: identity,
      name: name,
      fact: fact,
      topWeightKg: weightList.isEmpty
          ? 0
          : weightList.reduce((a, b) => a > b ? a : b),
      totalReps: repList.fold(0, (sum, value) => sum + value),
      setCount: repList.length,
      volumeKg: List.generate(
        repList.length,
        (index) => weightList[index] * repList[index],
      ).fold(0, (sum, value) => sum + value),
    );
  }

  final String identity;
  final String name;
  final Map<String, Object?> fact;
  final double topWeightKg;
  final int totalReps;
  final int setCount;
  final double volumeKg;
}

String _identity(TrainingExerciseIdentity value) =>
    '${value.exerciseKey}|${value.equipmentKey}';
