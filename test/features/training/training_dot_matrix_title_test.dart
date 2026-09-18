import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/training/training_page.dart';
import 'package:or_app/features/training/widgets/training_dot_matrix_title.dart';

void main() {
  test('TRAINING uses complete 5 by 7 LED glyph definitions', () {
    expect(TrainingDotMatrixGeometry.word.split(''), <String>[
      'T',
      'R',
      'A',
      'I',
      'N',
      'I',
      'N',
      'G',
    ]);
    for (final character in <String>{'T', 'R', 'A', 'I', 'N', 'G'}) {
      final glyph = TrainingDotMatrixGeometry.glyphs[character]!;
      expect(glyph, hasLength(TrainingDotMatrixGeometry.rowCount));
      expect(
        glyph.every(
          (row) => row.length == TrainingDotMatrixGeometry.columnCount,
        ),
        isTrue,
      );
      expect(glyph.join().contains('1'), isTrue);
    }
  });

  for (final width in <double>[320, 390, 900]) {
    testWidgets(
      'dot-matrix title stays centered and clear at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(const MaterialApp(home: TrainingPage()));

        final title = find.byKey(const ValueKey('training-page-appbar-title'));
        final appBar = find.byType(AppBar);
        expect(title, findsOneWidget);
        expect(find.byType(TrainingDotMatrixFrame), findsOneWidget);
        expect(find.bySemanticsLabel('TRAINING'), findsOneWidget);
        expect(
          tester.getCenter(title).dx,
          closeTo(tester.getCenter(appBar).dx, .5),
        );
        expect(tester.getRect(title).left, greaterThan(0));
        expect(tester.getRect(title).right, lessThan(width));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
