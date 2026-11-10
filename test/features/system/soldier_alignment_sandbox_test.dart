import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/soldier_alignment_sandbox.dart';

void main() {
  test('alignment data round-trips and rejects invalid frame contracts', () {
    const source = SoldierAlignmentData(
      frameOffsets: [
        Offset.zero,
        Offset(1, -.5),
        Offset(-1, .5),
        Offset.zero,
        Offset.zero,
        Offset.zero,
      ],
      offsetXdp: 4,
      offsetYdp: -2,
      scale: 1.05,
      brightness: .1,
      contrast: 1.1,
      saturation: .9,
      warmth: 3,
    );
    final restored = SoldierAlignmentData.tryParse(
      source.toJson(const Size(320, 320)),
    );
    expect(restored, isNotNull);
    expect(restored!.frameOffsets[1], const Offset(1, -.5));
    expect(restored.scale, 1.05);
    final invalid = source.toJson(const Size(320, 320))
      ..['frameOffsetsPx'] = [];
    expect(SoldierAlignmentData.tryParse(invalid), isNull);
  });

  testWidgets(
    'alignment sandbox exposes independent layer controls and copy/import',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SoldierAlignmentSandboxSection(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('SOLDIER ALIGNMENT'), findsOneWidget);
      expect(find.text('BREATHING'), findsOneWidget);
      expect(find.text('RIFLE REGRIP'), findsOneWidget);
      expect(find.text('TACTICAL GRID'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('copy-soldier-alignment-data')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('import-soldier-alignment-data')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
