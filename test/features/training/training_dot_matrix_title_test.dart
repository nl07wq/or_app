import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/theme/app_colors.dart';
import 'package:or_app/features/training/training_page.dart';
import 'package:or_app/features/training/widgets/training_dot_matrix_title.dart';

void main() {
  test('uses a 150px physical panel with a larger coherent LED matrix', () {
    expect(TrainingDotMatrixGeometry.panelWidth, 150);
    expect(TrainingDotMatrixGeometry.panelHeight, 36);
    expect(TrainingDotMatrixGeometry.glyphHeight, 20);
    expect(TrainingDotMatrixGeometry.dotPitch, 3);
    expect(TrainingDotMatrixGeometry.horizontalPadding, 11);
    expect(TrainingDotMatrixGeometry.surfaceMatrixColumnCount, 50);
    expect(TrainingDotMatrixGeometry.surfaceMatrixRowCount, 12);
    expect(TrainingDotMatrixGeometry.inactiveSurfaceDotCount, 600);
  });

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
    for (final character in <String>{
      'T',
      'R',
      'A',
      'I',
      'N',
      'G',
      'P',
      'L',
      'Y',
      'S',
      'E',
      'O',
      'C',
      'H',
      ' ',
    }) {
      final glyph = TrainingDotMatrixGeometry.glyphs[character]!;
      expect(glyph, hasLength(TrainingDotMatrixGeometry.rowCount));
      expect(
        glyph.every(
          (row) => row.length == TrainingDotMatrixGeometry.columnCount,
        ),
        isTrue,
      );
      expect(glyph.join().contains('1'), character == ' ' ? isFalse : isTrue);
    }
  });

  testWidgets(
    'normal titles use white LEDs and long titles scroll inside the fixed panel',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: TrainingDotMatrixTitle(title: 'TRAINING ANALYSIS REPORT'),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('TRAINING ANALYSIS REPORT'), findsOneWidget);
      expect(find.byType(TrainingDotMatrixFrame), findsOneWidget);
      final frame = tester.widget<TrainingDotMatrixFrame>(
        find.byType(TrainingDotMatrixFrame),
      );
      expect(frame.palette.active, TrainingDotMatrixGeometry.normalActiveColor);
      expect(frame.palette.inactive, isNot(const Color(0xFF4B2B1B)));
      expect(
        find.byKey(const ValueKey('training-dot-matrix-marquee')),
        findsOneWidget,
      );
      final glyph = tester.widget<TrainingDotMatrixGlyph>(
        find.byType(TrainingDotMatrixGlyph).first,
      );
      expect(glyph.activeColor, TrainingDotMatrixGeometry.normalActiveColor);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Reduced Motion keeps long titles static and state colors remain configurable',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: TrainingDotMatrixTitle(
                title: 'TRAINING REPORT SYNC',
                activeColor: AppColors.primary,
              ),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('TRAINING REPORT SYNC'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('training-dot-matrix-marquee')),
        findsNothing,
      );
      final glyph = tester.widget<TrainingDotMatrixGlyph>(
        find.byType(TrainingDotMatrixGlyph).first,
      );
      expect(glyph.activeColor, AppColors.primary);
      final frame = tester.widget<TrainingDotMatrixFrame>(
        find.byType(TrainingDotMatrixFrame),
      );
      expect(frame.palette.frame, AppColors.primary.withValues(alpha: .34));
      expect(tester.takeException(), isNull);
    },
  );

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
