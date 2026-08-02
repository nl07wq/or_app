import 'package:flutter/material.dart';

import '../../../core/widgets/operation_card.dart';
import '../../operation_date/services/operation_date_service.dart';
import '../../repositories/app_repository_container.dart';
import '../models/food_nutrition_aggregate.dart';
import '../models/food_unified_read_model.dart';

class FoodMixedSummaryCard extends StatelessWidget {
  final OperationDateService operationDateService;

  const FoodMixedSummaryCard({
    super.key,
    this.operationDateService = const OperationDateService(),
  });

  Future<FoodMixedDaySummary> _load() async {
    final date = (await operationDateService.current()).value;
    final records = await AppRepositoryRegistry.container.foodMixedRead
        .readForLocalDate(date);
    return FoodMixedDaySummary.fromRecords(records);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<FoodMixedDaySummary>(
    future: _load(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const OperationCard(
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return const OperationCard(
          child: Text('Unable to load current summary.'),
        );
      }
      final value = snapshot.data!;
      final aggregate = value.nutrition;
      final completeness = _overall(aggregate).name.toUpperCase();
      return OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$completeness · ${value.mealCount} meals'),
            Text('Known ${_known(aggregate.calories)} kcal'),
            Text(
              'P ${_known(aggregate.protein)} · F ${_known(aggregate.fat)} · C ${_known(aggregate.carbohydrate)}',
            ),
            Text('Water ${value.hydrationMl.toStringAsFixed(0)} ml'),
          ],
        ),
      );
    },
  );
}

FoodNutritionCompleteness _overall(FoodNutritionAggregate value) {
  final states = [
    value.calories,
    value.protein,
    value.fat,
    value.carbohydrate,
  ].map((item) => item.completeness).toList();
  if (states.every((value) => value == FoodNutritionCompleteness.complete)) {
    return FoodNutritionCompleteness.complete;
  }
  if (states.every((value) => value == FoodNutritionCompleteness.unknown)) {
    return FoodNutritionCompleteness.unknown;
  }
  return FoodNutritionCompleteness.partial;
}

String _known(FoodNutritionValueAggregate value) =>
    value.knownItemCount == 0 ? 'Unknown' : value.knownTotal.toStringAsFixed(1);
