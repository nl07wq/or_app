import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/training/widgets/training_ambient_comparison.dart';

void main() {
  testWidgets(
    'TRAINING ambient comparison exposes and switches all candidates',
    (tester) async {
      TrainingAmbientVariant selected = TrainingAmbientVariant.magneticFlux;
      late StateSetter update;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Scaffold(
                body: Stack(
                  children: [
                    TrainingAmbientComparison(variant: selected),
                    TrainingAmbientComparisonSelector(
                      selected: selected,
                      onChanged: (variant) =>
                          setState(() => selected = variant),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      expect(TrainingAmbientVariant.values, hasLength(3));
      expect(find.byType(TrainingAmbientComparison), findsOneWidget);
      expect(find.text('MAGNETIC FLUX'), findsOneWidget);
      expect(find.text('KINETIC ENGINE'), findsOneWidget);
      expect(find.text('VECTOR IMPULSE'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('training-ambient-vectorImpulse')),
      );
      await tester.pump();

      expect(selected, TrainingAmbientVariant.vectorImpulse);
      for (final variant in TrainingAmbientVariant.values) {
        expect(
          TrainingAmbientComparison.motionSignatureFor(variant, 0),
          isNot(TrainingAmbientComparison.motionSignatureFor(variant, 3.75)),
        );
        update(() => selected = variant);
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.takeException(), isNull);
      }
    },
  );
}
