import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/cardio_entry_v2.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/training_equipment_snapshot.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/core/theme/app_colors.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/status/models/persisted_status_record.dart';
import 'package:or_app/features/training/models/active_training_draft.dart';
import 'package:or_app/features/training/models/training_record_read_model.dart';
import 'package:or_app/features/training/repository/active_training_draft_repository.dart';
import 'package:or_app/features/training/repository/indexed_db_active_training_draft_repository.dart';
import 'package:or_app/features/training/services/training_v2_form_mapper.dart';
import 'package:or_app/features/training/training_entry_page.dart';
import 'package:or_app/features/training/widgets/exercise_selector.dart';
import 'package:or_app/features/training/widgets/training_cardio_v2_editor.dart';
import 'package:or_app/features/training/widgets/training_exercise_v2_editor.dart';
import 'package:or_app/features/training/widgets/training_dot_matrix_title.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../operation_date/operation_date_test_fixture.dart';

void main() {
  setUp(AppRepositoryRegistry.resetForTesting);
  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets('new v2 entry exposes session and set fields at 320px', (
    tester,
  ) async {
    await _pump(tester, width: 320);

    expect(find.text('SESSION NAME'), findsOneWidget);
    expect(find.text('START TIME'), findsOneWidget);
    expect(find.text('END TIME'), findsOneWidget);
    expect(find.text('Start Time'), findsNothing);
    expect(find.text('End Time'), findsNothing);
    expect(find.text('Session Grade'), findsNothing);
    expect(find.text('SESSION MEMO'), findsOneWidget);
    expect(find.text('DYNAMIC STRETCH'), findsOneWidget);
    expect(find.text('COOLDOWN STRETCH'), findsOneWidget);
    expect(find.text('Overall Evaluation'), findsNothing);
    expect(find.text('Evaluation'), findsNothing);
    expect(find.text('Next Target'), findsNothing);
    expect(find.text('PROGRESSION'), findsNothing);
    expect(find.text('PERSONAL RECORD'), findsNothing);
    expect(find.text('SELECT EXERCISE'), findsOneWidget);
    expect(find.text('EQUIPMENT'), findsOneWidget);
    expect(find.text('SET TYPE'), findsOneWidget);
    expect(find.text('RPE'), findsOneWidget);
    expect(find.text('REST'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('30')).dy,
      tester.getTopLeft(find.text('120')).dy,
    );
    final weightTop = tester
        .getTopLeft(find.byKey(const Key('v2-set-0-weight')))
        .dy;
    final repsTop = tester
        .getTopLeft(find.byKey(const Key('v2-set-0-reps')))
        .dy;
    expect(weightTop, repsTop);
    expect(find.text('SAVE TRAINING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'active title keeps its center while each glyph travels to its slot',
    (tester) async {
      await _pump(tester, width: 390, disableAnimations: false);
      final title = find.byKey(const ValueKey('training-appbar-title'));
      expect(tester.getCenter(title).dx, closeTo(195, 0.5));
      expect(find.byType(TrainingDotMatrixFrame), findsOneWidget);
      expect(find.bySemanticsLabel('TRAINING'), findsOneWidget);
      expect(
        tester
            .widget<TrainingDotMatrixGlyph>(
              find.byType(TrainingDotMatrixGlyph).first,
            )
            .activeColor,
        AppColors.primary,
      );
      expect(
        tester
            .widget<TrainingDotMatrixFrame>(find.byType(TrainingDotMatrixFrame))
            .palette
            .frame,
        AppColors.primary.withValues(alpha: .34),
      );

      await tester.tap(find.text('START TRAINING'));
      await tester.pump();
      expect(find.text('ACTIVE'), findsWidgets);
      expect(
        tester
            .widget<TrainingDotMatrixGlyph>(
              find.byType(TrainingDotMatrixGlyph).first,
            )
            .activeColor,
        AppColors.success,
      );
      expect(
        tester
            .widget<TrainingDotMatrixFrame>(find.byType(TrainingDotMatrixFrame))
            .palette
            .frame,
        AppColors.success.withValues(alpha: .34),
      );

      final travellingT = find.byKey(
        const ValueKey('training-title-travelling-0'),
      );
      final tSlot = find.byKey(const ValueKey('training-title-slot-0'));
      expect(travellingT, findsOneWidget);
      final titleBounds = tester.getRect(title);
      final tStart = tester.getRect(travellingT);
      expect(tStart.left, greaterThan(tester.getTopLeft(tSlot).dx + 40));
      expect(tStart.left, greaterThanOrEqualTo(titleBounds.left));
      expect(tStart.right, lessThanOrEqualTo(titleBounds.right));

      // T lands after its 420ms travel, then R starts only after the 120ms
      // settle. The R glyph is independently translated rather than faded in.
      await tester.pump(const Duration(milliseconds: 540));
      final travellingR = find.byKey(
        const ValueKey('training-title-travelling-1'),
      );
      final rSlot = find.byKey(const ValueKey('training-title-slot-1'));
      expect(find.byKey(const ValueKey('training-title-settled-1')), findsOne);
      expect(travellingR, findsOneWidget);
      final rStart = tester.getTopLeft(travellingR).dx;
      final rDestination = tester.getTopLeft(rSlot).dx;
      expect(rStart, greaterThan(rDestination + 40));
      expect(
        tester.getRect(travellingR).left,
        greaterThanOrEqualTo(titleBounds.left),
      );
      expect(
        tester.getRect(travellingR).right,
        lessThanOrEqualTo(titleBounds.right),
      );

      await tester.pump(const Duration(milliseconds: 210));
      final rMidpoint = tester.getTopLeft(travellingR).dx;
      expect(rMidpoint, lessThan(rStart));
      expect(rMidpoint, greaterThan(rDestination + 1));

      await tester.pump(const Duration(milliseconds: 210));
      expect(
        find.byKey(const ValueKey('training-title-travelling-1')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('training-title-settled-2')), findsOne);
      expect(tester.getCenter(title).dx, closeTo(195, 0.5));

      // The complete word is held for 900ms before the loop resets.
      await tester.pump(const Duration(milliseconds: 3360));
      expect(find.byKey(const ValueKey('training-title-settled-8')), findsOne);
      await tester.pump(const Duration(milliseconds: 899));
      expect(find.byKey(const ValueKey('training-title-settled-8')), findsOne);
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        find.byKey(const ValueKey('training-title-travelling-0')),
        findsOne,
      );

      await tester.tap(find.text('PAUSE TRAINING'));
      await tester.pump();
      expect(find.text('PAUSED'), findsWidgets);
      expect(
        tester
            .widget<TrainingDotMatrixGlyph>(
              find.byType(TrainingDotMatrixGlyph).first,
            )
            .activeColor,
        AppColors.warning,
      );
      expect(
        tester
            .widget<TrainingDotMatrixFrame>(find.byType(TrainingDotMatrixFrame))
            .palette
            .frame,
        AppColors.warning.withValues(alpha: .34),
      );
      expect(tester.getCenter(title).dx, closeTo(195, 0.5));
    },
  );

  for (final width in <double>[320, 390, 900]) {
    testWidgets(
      'dot-matrix entry title clears the overflow action at ${width.toInt()}px',
      (tester) async {
        await _pump(tester, width: width, disableAnimations: false);
        await tester.tap(find.text('START TRAINING'));
        await tester.pump();

        final title = tester.getRect(
          find.byKey(const ValueKey('training-appbar-title')),
        );
        final overflow = tester.getRect(find.byIcon(Icons.more_vert));
        expect(title.center.dx, closeTo(width / 2, .5));
        expect(title.right, lessThan(overflow.left));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in <double>[390, 900, 1280]) {
    testWidgets('new v2 entry has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      await _pump(tester, width: width);

      expect(find.text('SAVE TRAINING'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('new v2 entry has no overflow in dark theme', (tester) async {
    await _pump(tester, width: 390, brightness: Brightness.dark);

    expect(find.text('SAVE TRAINING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[320, 390]) {
    testWidgets(
      'rest presets keep one compact hit row and seconds at ${width.toInt()}px',
      (tester) async {
        await _pump(tester, width: width);
        final restField = find.byKey(const Key('v2-set-0-rest'));
        const presets = [30, 45, 60, 90, 120];
        double? rowTop;

        for (final seconds in presets) {
          final button = find.widgetWithText(OutlinedButton, '$seconds');
          expect(button, findsOneWidget);
          final rect = tester.getRect(button);
          rowTop ??= rect.top;
          expect(rect.top, rowTop);
          expect(rect.height, greaterThanOrEqualTo(38));
          final outlined = tester.widget<OutlinedButton>(button);
          final shape = outlined.style!.shape!.resolve({});
          expect(shape, isA<RoundedRectangleBorder>());
          final radius = (shape! as RoundedRectangleBorder).borderRadius
              .resolve(TextDirection.ltr)
              .topLeft
              .x;
          expect(radius, lessThan(rect.height / 2));
          await tester.tapAt(Offset(rect.center.dx, rect.bottom - 1));
          await tester.pump();
          expect(
            tester.widget<TextField>(restField).controller!.text,
            '$seconds',
          );
          final selectedButton = tester.widget<OutlinedButton>(button);
          expect(
            selectedButton.style!.backgroundColor!.resolve({}),
            Theme.of(tester.element(button)).colorScheme.primaryContainer,
          );
        }

        await tester.enterText(restField, '75');
        expect(tester.widget<TextField>(restField).controller!.text, '75');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('390px keeps set type in the header and numeric inputs paired', (
    tester,
  ) async {
    await _pump(tester, width: 390);

    final setType = tester.getRect(find.byKey(const Key('v2-set-0-type')));
    final weight = tester.getRect(find.byKey(const Key('v2-set-0-weight')));
    final reps = tester.getRect(find.byKey(const Key('v2-set-0-reps')));
    final rpe = tester.getRect(find.byKey(const Key('v2-set-0-rpe')));
    final rest = tester.getRect(find.byKey(const Key('v2-set-0-rest')));

    expect(setType.bottom, lessThanOrEqualTo(weight.top));
    expect(weight.top, closeTo(reps.top, 2));
    expect(weight.right, lessThan(reps.left));
    expect(weight.width, closeTo(reps.width, 1));
    expect(rpe.top, closeTo(rest.top, 2));
    expect(rpe.right, lessThan(rest.left));
    expect(rpe.top, greaterThan(weight.bottom));
  });

  for (final width in <double>[320, 390, 900]) {
    testWidgets('session memo keeps a balanced multiline field at '
        '${width.toInt()}px', (tester) async {
      await _pump(tester, width: width);

      final sessionName = find.widgetWithText(TextField, 'SESSION NAME');
      final sessionMemo = find.widgetWithText(TextField, 'SESSION MEMO');
      final memoField = tester.widget<TextField>(sessionMemo);

      expect(memoField.minLines, 2);
      expect(memoField.maxLines, 3);
      expect(
        tester.getSize(sessionMemo).height,
        greaterThan(tester.getSize(sessionName).height * 1.35),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('training selectors use the compact 14px value typography', (
    tester,
  ) async {
    await _pump(tester, width: 390);
    const compactValueSize = 14.0;

    TextStyle? selectedStyle(Finder field) {
      final dropdown = find.descendant(
        of: field,
        matching: find.byWidgetPredicate((widget) => widget is DropdownButton),
      );
      return tester.widget<DropdownButton<dynamic>>(dropdown).style;
    }

    for (final field in [
      find.byType(DropdownButtonFormField<String>).first,
      find.byType(DropdownButtonFormField<TrainingSetType>),
      find.byType(DropdownButtonFormField<int?>),
    ]) {
      expect(selectedStyle(field)!.fontSize, compactValueSize);
    }
    expect(
      tester.widget<Text>(find.text('SELECT EXERCISE')).style!.fontSize,
      compactValueSize,
    );
    expect(
      tester.widget<Text>(find.text('EQUIPMENT')).style!.fontSize,
      compactValueSize,
    );

    await tester.tap(find.text('ADD CARDIO'));
    await tester.pumpAndSettle();
    for (final field in [
      find.byType(DropdownButtonFormField<CardioType?>),
      find.byType(DropdownButtonFormField<CardioPurpose?>),
    ]) {
      expect(selectedStyle(field)!.fontSize, compactValueSize);
    }
  });

  for (final width in <double>[320, 390]) {
    testWidgets('weight and reps controls stay paired in compact grids at '
        '${width.toInt()}px', (tester) async {
      await _pump(tester, width: width);
      final weightGrid = find.byKey(const Key('v2-set-0-weight-adjustments'));
      final repsGrid = find.byKey(const Key('v2-set-0-reps-adjustments'));
      final weightRect = tester.getRect(weightGrid);
      final repsRect = tester.getRect(repsGrid);

      expect(weightRect.right, lessThan(repsRect.left));
      expect(
        tester.getTopLeft(find.byKey(const Key('v2-set-0-weight'))).dx,
        lessThan(tester.getTopLeft(find.byKey(const Key('v2-set-0-reps'))).dx),
      );
      _expectAdjustmentGrid(
        tester,
        grid: weightGrid,
        labels: const ['-10', '-5', '-2.5', '+2.5', '+5', '+10'],
      );
      _expectAdjustmentGrid(
        tester,
        grid: repsGrid,
        labels: const ['-10', '-5', '-1', '+1', '+5', '+10'],
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    for (final width in <double>[320, 390, 900, 1280]) {
      testWidgets(
        'cardio editor has localized single inputs without overflow at '
        '${width.toInt()}px ${brightness.name}',
        (tester) async {
          await _pump(tester, width: width, brightness: brightness);
          await tester.tap(find.text('ADD CARDIO'));
          await tester.pumpAndSettle();

          expect(find.text('SELECT CARDIO'), findsOneWidget);
          expect(find.text('SELECT PURPOSE'), findsOneWidget);
          expect(find.text('時間'), findsOneWidget);
          expect(find.text('距離'), findsOneWidget);
          expect(find.text('METs'), findsOneWidget);
          expect(find.text('平均心拍'), findsOneWidget);
          expect(find.text('最大心拍'), findsOneWidget);
          expect(find.text('平均速度'), findsOneWidget);
          expect(find.text('推定消費カロリー'), findsOneWidget);
          expect(find.text('メモ'), findsOneWidget);
          expect(
            find.byKey(
              ValueKey(
                width >= 390
                    ? 'training-cardio-two-column'
                    : 'training-cardio-one-column',
              ),
            ),
            findsOneWidget,
          );
          if (width >= 390) {
            final purpose = tester.getRect(
              find.byKey(const Key('v2-cardio-0-purpose')),
            );
            final duration = tester.getRect(
              find.byKey(const Key('v2-cardio-0-duration')),
            );
            expect(purpose.center.dy, closeTo(duration.center.dy, 1));
            expect(purpose.right, lessThan(duration.left));
          }
          expect(find.text('Minutes'), findsNothing);
          expect(find.text('Seconds'), findsNothing);
          expect(find.byKey(const Key('v2-cardio-0-equipment')), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('cardio selectors keep separate stable values and copy', (
    tester,
  ) async {
    final database = await _pump(tester);
    await tester.tap(find.text('ADD CARDIO'));
    await tester.pumpAndSettle();

    final typeField = find.byKey(const Key('v2-cardio-0-type'));
    final purposeField = find.byKey(const Key('v2-cardio-0-purpose'));
    expect(typeField, findsOneWidget);
    expect(purposeField, findsOneWidget);

    await tester.tap(typeField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ランニング').last);
    await tester.pumpAndSettle();

    await tester.tap(purposeField);
    await tester.pumpAndSettle();
    expect(find.text('WARM-UP'), findsOneWidget);
    expect(find.text('MAIN'), findsOneWidget);
    expect(find.text('COOL-DOWN'), findsOneWidget);
    await tester.tap(find.text('MAIN'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('v2-cardio-0-duration')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cardio-duration-minutes')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('05').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('APPLY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE TRAINING'));
    await tester.pumpAndSettle();

    final records = await database.findAll(IndexedDbStoreNames.trainingRecords);
    final data = records.single['data'] as Map<String, dynamic>;
    final cardio =
        (data['cardioEntries'] as List).single as Map<String, dynamic>;
    expect(cardio['type'], CardioType.running.name);
    expect(cardio['purpose'], CardioPurpose.main.stableId);
    expect(cardio['durationSeconds'], 300);
  });

  testWidgets('cardio duration selectors update draft values live and commit '
      'only on APPLY', (tester) async {
    await _pump(tester, width: 390);
    await tester.tap(find.text('ADD CARDIO'));
    await tester.pumpAndSettle();

    final cardio = tester.widget<TrainingCardioV2Editor>(
      find.byType(TrainingCardioV2Editor),
    );
    await tester.tap(find.byKey(const Key('v2-cardio-0-duration')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cardio-duration-hours')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('cardio-duration-hours-value-12')),
      findsOneWidget,
    );
    expect(cardio.controller.duration.text, isEmpty);

    await tester.tap(find.byKey(const ValueKey('cardio-duration-minutes')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('34').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('cardio-duration-minutes-value-34')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('cardio-duration-seconds')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('56'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('56').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('cardio-duration-seconds-value-56')),
      findsOneWidget,
    );

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(cardio.controller.duration.text, isEmpty);

    await tester.tap(find.byKey(const Key('v2-cardio-0-duration')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('cardio-duration-hours-value-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cardio-duration-minutes-value-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cardio-duration-seconds-value-0')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('cardio-duration-hours')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('02').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cardio-duration-minutes')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cardio-duration-seconds')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('APPLY'));
    await tester.pumpAndSettle();

    expect(cardio.controller.duration.text, '2:15:30');
    expect(
      TrainingV2FormMapper.parseDurationSeconds(
        cardio.controller.duration.text,
      ),
      8130,
    );

    await tester.tap(find.byKey(const Key('v2-cardio-0-duration')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('cardio-duration-hours-value-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cardio-duration-minutes-value-15')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cardio-duration-seconds-value-30')),
      findsOneWidget,
    );
  });

  for (final width in <double>[320, 390, 900]) {
    testWidgets('cardio duration selector geometry remains readable at '
        '${width.toInt()}px', (tester) async {
      await _pump(tester, width: width);
      await tester.tap(find.text('ADD CARDIO'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('v2-cardio-0-duration')));
      await tester.pumpAndSettle();

      final fields = [
        find.byKey(const ValueKey('cardio-duration-hours')),
        find.byKey(const ValueKey('cardio-duration-minutes')),
        find.byKey(const ValueKey('cardio-duration-seconds')),
      ];
      final labels = ['HOURS', 'MINUTES', 'SECONDS'];
      for (var index = 0; index < fields.length; index++) {
        final fieldRect = tester.getRect(fields[index]);
        expect(fieldRect.width, 76);
        final label = find.descendant(
          of: fields[index],
          matching: find.text(labels[index]),
        );
        final value = find.descendant(
          of: fields[index],
          matching: find.text('00'),
        );
        final chevron = find.descendant(
          of: fields[index],
          matching: find.byIcon(Icons.arrow_drop_down),
        );
        expect(label, findsOneWidget);
        expect(value, findsOneWidget);
        expect(chevron, findsOneWidget);
        expect(tester.getRect(label).right, lessThanOrEqualTo(fieldRect.right));
        expect(
          tester.getRect(value).right,
          lessThan(tester.getRect(chevron).left),
        );
      }

      final hours = tester.getRect(fields[0]);
      final minutes = tester.getRect(fields[1]);
      final seconds = tester.getRect(fields[2]);
      if (width < 360) {
        expect(hours.top, closeTo(minutes.top, 1));
        expect(seconds.top, greaterThan(hours.bottom));
      } else {
        expect(hours.top, closeTo(minutes.top, 1));
        expect(minutes.top, closeTo(seconds.top, 1));
      }
      expect(find.byTooltip('Increase hours'), findsNothing);
      expect(find.byTooltip('Decrease hours'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ADD SET preserves copy actions and rest presets', (
    tester,
  ) async {
    await _pump(tester);

    await tester.enterText(find.widgetWithText(TextField, 'WEIGHT'), '80');
    await tester.enterText(find.widgetWithText(TextField, 'REPS'), '8');
    await tester.tap(find.text('90'));
    await tester.tap(find.text('ADD SET'));
    await tester.pumpAndSettle();

    expect(find.text('SET 2'), findsOneWidget);
    expect(find.byTooltip('Copy previous weight'), findsOneWidget);
    expect(find.byTooltip('Copy previous reps'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy previous weight'));
    await tester.tap(find.byTooltip('Copy previous reps'));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('v2-set-1-weight')))
          .controller!
          .text,
      '80',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('v2-set-1-reps')))
          .controller!
          .text,
      '8',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('v2-set-1-rest')))
          .controller!
          .text,
      '90',
    );
  });

  testWidgets('SET TYPE retains one fixed header slot across set counts', (
    tester,
  ) async {
    await _pump(tester, width: 390);
    for (var index = 0; index < 9; index++) {
      await tester.ensureVisible(find.text('ADD SET'));
      await tester.tap(find.text('ADD SET'));
      await tester.pumpAndSettle();
    }

    final typeRects = <Rect>[
      for (final index in [0, 1, 2, 9])
        tester.getRect(find.byKey(Key('v2-set-$index-type'))),
    ];
    for (final rect in typeRects.skip(1)) {
      expect(rect.left, closeTo(typeRects.first.left, .1));
      expect(rect.width, closeTo(typeRects.first.width, .1));
    }

    final deleteRects = <Rect>[
      for (final index in [0, 1, 2, 9])
        tester.getRect(find.byKey(Key('v2-set-$index-delete'))),
    ];
    for (final rect in deleteRects.skip(1)) {
      expect(rect.left, closeTo(deleteRects.first.left, .1));
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('training-set-card-0')),
        matching: find.byType(IconButton),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('training-set-card-1')),
        matching: find.byType(IconButton),
      ),
      findsNWidgets(3),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('SET TYPE header slots remain stable at supported widths', (
    tester,
  ) async {
    for (final width in [320.0, 390.0, 900.0]) {
      await _pump(tester, width: width);
      await tester.tap(find.text('ADD SET'));
      await tester.pumpAndSettle();

      final first = tester.getRect(find.byKey(const Key('v2-set-0-type')));
      final second = tester.getRect(find.byKey(const Key('v2-set-1-type')));
      expect(first.left, closeTo(second.left, .1));
      expect(first.width, closeTo(second.width, .1));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('weight and reps adjustment buttons update safely', (
    tester,
  ) async {
    await _pump(tester, width: 320);
    await tester.enterText(find.byKey(const Key('v2-set-0-weight')), '80');
    await tester.enterText(find.byKey(const Key('v2-set-0-reps')), '5');

    final weightAdjustments = find.byKey(
      const Key('v2-set-0-weight-adjustments'),
    );
    final repsAdjustments = find.byKey(const Key('v2-set-0-reps-adjustments'));
    await tester.tap(
      find.descendant(of: weightAdjustments, matching: find.text('+2.5')),
    );
    await tester.tap(
      find.descendant(of: repsAdjustments, matching: find.text('-10')),
    );

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('v2-set-0-weight')))
          .controller!
          .text,
      '82.5',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('v2-set-0-reps')))
          .controller!
          .text,
      '0',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('equipment accepts built-in, none, and custom snapshots', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('EQUIPMENT'), findsOneWidget);
    expect(find.text('なし'), findsNothing);
    _setExercise(tester, 'BenchPress');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-exercise-0-equipment')));
    await tester.pumpAndSettle();
    expect(find.text('なし'), findsOneWidget);
    expect(find.text('CUSTOM EQUIPMENT'), findsOneWidget);
    expect(find.text('45°レッグプレス'), findsNothing);
    final builtIn = find.text('パワーラック').first;
    await tester.tap(builtIn);
    await tester.pumpAndSettle();
    expect(find.text('パワーラック'), findsOneWidget);

    await tester.tap(find.byKey(const Key('v2-exercise-0-equipment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CUSTOM EQUIPMENT'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'EQUIPMENT NAME'),
      'Custom Handle',
    );
    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    expect(find.text('Custom Handle'), findsOneWidget);

    await tester.tap(find.byKey(const Key('v2-exercise-0-equipment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('なし').last);
    await tester.pumpAndSettle();
    expect(find.text('なし'), findsOneWidget);
  });

  testWidgets('exercise change preserves only compatible equipment', (
    tester,
  ) async {
    await _pump(tester);
    _setExercise(tester, 'BenchPress');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-exercise-0-equipment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('スミスマシン'));
    await tester.pumpAndSettle();

    _setExercise(tester, 'ShoulderPress');
    await tester.pumpAndSettle();
    expect(find.text('スミスマシン'), findsOneWidget);

    _setExercise(tester, 'LegPress');
    await tester.pumpAndSettle();
    expect(find.text('EQUIPMENT'), findsOneWidget);
    expect(find.text('なし'), findsNothing);
  });

  testWidgets('insight panels precede sets and omit responsibility fields', (
    tester,
  ) async {
    await _pump(tester, width: 320);
    _setExercise(tester, 'BenchPress');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-exercise-0-equipment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('なし'));
    await tester.pumpAndSettle();

    final previous = tester.getTopLeft(find.text('PREVIOUS')).dy;
    final progression = tester.getTopLeft(find.text('PROGRESSION')).dy;
    final personalRecord = tester.getTopLeft(find.text('PERSONAL RECORD')).dy;
    final firstSet = tester.getTopLeft(find.text('SET 1')).dy;
    expect(previous, lessThan(progression));
    expect(progression, lessThan(personalRecord));
    expect(personalRecord, lessThan(firstSet));
    expect(find.text('STATISTICS'), findsNothing);
    expect(find.text('前回　記録なし'), findsOneWidget);
    expect(find.text('今回　提案なし'), findsOneWidget);
    expect(find.text('自己ベスト'), findsOneWidget);
    expect(find.text('Overall Evaluation'), findsNothing);
    expect(find.text('Evaluation'), findsNothing);
    expect(find.text('Next Target'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('statistics results stay outside entry for valid main sets', (
    tester,
  ) async {
    await _pump(tester, width: 320);
    _setExercise(tester, 'BenchPress');
    await tester.enterText(find.byKey(const Key('v2-set-0-weight')), '80');
    await tester.enterText(find.byKey(const Key('v2-set-0-reps')), '8');
    await tester.pump();

    expect(find.text('STATISTICS'), findsNothing);
    expect(find.text('総重量 640 kg'), findsNothing);
    expect(find.text('セット数 1'), findsNothing);
    expect(find.text('総レップ数 8'), findsNothing);
    expect(find.text('平均重量 80 kg'), findsNothing);
    expect(find.text('最高重量 80 kg × 8'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing sets preserves hidden evaluation and next target', (
    tester,
  ) async {
    final database = FakeIndexedDbDatabase();
    final existing = TrainingRecordReadModel.v2(
      id: 'training:11112222-3333-4444-8555-666677778888',
      localDate: '2026-07-30',
      createdAt: DateTime.utc(2026, 7, 30),
      updatedAt: DateTime.utc(2026, 7, 30),
      data: TrainingSessionV2(
        date: '2026-07-30T12:00:00',
        sessionGrade: TrainingSessionGrade.a,
        overallEvaluation: 'Keep session evaluation',
        exercises: [
          TrainingExerciseV2(
            exerciseName: 'BenchPress',
            order: 1,
            equipment: TrainingEquipmentSnapshot(
              catalogId: 'power_rack',
              name: 'Power Rack',
            ),
            sets: [
              TrainingSetV2(
                setNo: 1,
                setType: TrainingSetType.main,
                weightKg: 80,
                reps: 5,
              ),
            ],
            evaluation: 'Keep exercise evaluation',
            nextTarget: TrainingNextTarget(
              targetWeightKg: 82.5,
              targetReps: [5],
              notes: 'Keep target',
            ),
          ),
        ],
      ),
    );
    database.seed(IndexedDbStoreNames.trainingRecords, existing.id, {
      'id': existing.id,
      'recordVersion': 2,
      'localDate': existing.localDate,
      'createdAt': existing.createdAt.toIso8601String(),
      'updatedAt': existing.updatedAt.toIso8601String(),
      'data': existing.v2Data!.toJson(),
    });
    await _pump(tester, existingRecord: existing, database: database);

    await tester.tap(find.bySemanticsLabel('ベンチプレス, collapsed'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'REPS'), '6');
    await tester.tap(find.text('UPDATE TRAINING'));
    await tester.pumpAndSettle();

    final stored = await database.findById(
      IndexedDbStoreNames.trainingRecords,
      existing.id,
    );
    final data = stored!['data'] as Map<String, dynamic>;
    final exercise = (data['exercises'] as List).single as Map<String, dynamic>;
    expect(data['sessionGrade'], 'a');
    expect(data['overallEvaluation'], 'Keep session evaluation');
    expect(exercise['evaluation'], 'Keep exercise evaluation');
    expect(exercise['nextTarget'], containsPair('targetWeightKg', 82.5));
    expect(exercise['nextTarget'], containsPair('notes', 'Keep target'));
  });

  testWidgets('editable v2 restores fields and cardio calories stay disabled', (
    tester,
  ) async {
    final record = TrainingRecordReadModel.v2(
      id: 'training:00112233-4455-4677-8899-aabbccddeeff',
      localDate: '2026-07-30',
      createdAt: DateTime.utc(2026, 7, 30),
      updatedAt: DateTime.utc(2026, 7, 30),
      data: TrainingSessionV2(
        date: '2026-07-30T12:00:00',
        sessionName: 'Express',
        cardioEntries: [
          CardioEntryV2(
            purpose: CardioPurpose.main,
            type: CardioType.running,
            durationSeconds: 125,
            mets: 7,
            averageHeartRateBpm: 130,
            maximumHeartRateBpm: 150,
            averageSpeedKmh: 11,
          ),
        ],
      ),
    );

    await _pump(tester, existingRecord: record);

    expect(find.text('UPDATE TRAINING'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'SESSION NAME'))
          .controller!
          .text,
      'Express',
    );
    expect(find.bySemanticsLabel('ランニング, collapsed'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('ランニング, collapsed'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '時間'))
          .controller!
          .text,
      '2:05',
    );
    expect(find.text('推定消費カロリー'), findsOneWidget);
    expect(find.text('EQUIPMENT'), findsNothing);
    expect(find.text('Minutes'), findsNothing);
    expect(find.text('Seconds'), findsNothing);
    expect(find.text('SELECT CARDIO'), findsNothing);
    expect(find.text('SELECT PURPOSE'), findsNothing);
    expect(find.text('距離'), findsOneWidget);
    expect(find.text('平均心拍'), findsOneWidget);
    expect(find.text('最大心拍'), findsOneWidget);
    expect(find.text('平均速度'), findsOneWidget);
    expect(find.text('メモ'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '平均速度'))
          .keyboardType,
      TextInputType.text,
    );
    expect(find.text('NOT CALCULATED'), findsOneWidget);
    expect(find.text('Not calculated'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('double SAVE TRAINING creates only one v2 record', (
    tester,
  ) async {
    final database = await _pump(tester);
    tester
            .widget<ExerciseSelector>(find.byType(ExerciseSelector))
            .controller
            .text =
        'Squat';
    await tester.enterText(find.widgetWithText(TextField, 'WEIGHT'), '80');
    await tester.enterText(find.widgetWithText(TextField, 'REPS'), '5');

    final save = find.text('SAVE TRAINING');
    await tester.tap(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final records = await database.findAll(IndexedDbStoreNames.trainingRecords);
    expect(records, hasLength(1));
    expect(records.single['recordVersion'], 2);
  });

  testWidgets('successful save asks whether to create a Training Report', (
    tester,
  ) async {
    final database = await _pump(tester);
    _setExercise(tester, 'Squat');
    await tester.enterText(find.widgetWithText(TextField, 'WEIGHT'), '80');
    await tester.enterText(find.widgetWithText(TextField, 'REPS'), '5');

    await tester.tap(find.text('SAVE TRAINING'));
    await tester.pumpAndSettle();

    expect(find.text('TRAINING REPORT'), findsOneWidget);
    expect(find.text('YES'), findsOneWidget);
    expect(find.text('NO'), findsOneWidget);
    expect(
      await database.findAll(IndexedDbStoreNames.trainingRecords),
      hasLength(1),
    );

    await tester.tap(find.text('NO'));
    await tester.pumpAndSettle();
    expect(find.text('TRAINING REPORT'), findsNothing);
  });

  testWidgets('Active Training Draft restores and is deleted after save', (
    tester,
  ) async {
    final database = FakeIndexedDbDatabase();
    final drafts = IndexedDbActiveTrainingDraftRepository(database);
    await _pump(
      tester,
      database: database,
      activeTrainingDraftRepository: drafts,
    );
    expect(
      _trainingTheme(tester, active: false).colorScheme.primary,
      AppColors.primary,
    );

    await tester.tap(find.text('START TRAINING'));
    await tester.pump();
    expect(find.text('ACTIVE'), findsWidgets);
    expect(
      _trainingTheme(tester, active: true).colorScheme.primary,
      AppColors.success,
    );
    final operationDate =
        (await database.findAll(
              IndexedDbStoreNames.operationState,
            )).single['operationDate']
            as String;
    final draftId = 'active-training-draft:$operationDate';
    expect(
      database.rawRecord(IndexedDbStoreNames.activeTrainingDrafts, draftId),
      containsPair('endTime', null),
    );
    expect(
      await database.findAll(IndexedDbStoreNames.trainingRecords),
      isEmpty,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'SESSION NAME'),
      'Persisted Session',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'SESSION MEMO'),
      'Reload-safe memo',
    );
    _setExercise(tester, 'Squat');
    await tester.enterText(find.widgetWithText(TextField, 'WEIGHT'), '80');
    await tester.enterText(find.widgetWithText(TextField, 'REPS'), '5');
    await tester.ensureVisible(find.text('ADD SET'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADD SET'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('v2-set-1-weight')), '75');
    await tester.enterText(find.byKey(const Key('v2-set-1-reps')), '8');
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(
      tester,
      database: database,
      activeTrainingDraftRepository: drafts,
      settle: false,
    );
    expect(find.text('ELAPSED'), findsOneWidget);
    expect(find.text('PAUSE TRAINING'), findsOneWidget);
    expect(find.text('ACTIVE'), findsWidgets);
    expect(
      _trainingTheme(tester, active: true).colorScheme.primary,
      AppColors.success,
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'SESSION NAME'))
          .controller
          ?.text,
      'Persisted Session',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'SESSION MEMO'))
          .controller
          ?.text,
      'Reload-safe memo',
    );
    final restoredExercise = tester
        .widget<TrainingExerciseV2Editor>(find.byType(TrainingExerciseV2Editor))
        .controller;
    expect(restoredExercise.exerciseName.text, 'Squat');
    expect(restoredExercise.sets.map((value) => value.weight.text), [
      '80',
      '75',
    ]);
    expect(restoredExercise.sets.map((value) => value.reps.text), ['5', '8']);

    await tester.tap(find.text('PAUSE TRAINING'));
    await tester.pump();
    expect(find.text('PAUSED'), findsWidgets);
    expect(
      tester
          .widget<Theme>(find.byKey(const ValueKey('training-amber-base')))
          .data
          .colorScheme
          .primary,
      AppColors.warning,
    );
    expect(
      database.rawRecord(IndexedDbStoreNames.activeTrainingDrafts, draftId),
      containsPair('endTime', null),
    );
    expect(find.text('DURATION'), findsNothing);

    await tester.tap(find.text('RESUME TRAINING'));
    await tester.pump();
    expect(find.text('ACTIVE'), findsWidgets);
    expect(
      database.rawRecord(IndexedDbStoreNames.activeTrainingDrafts, draftId),
      containsPair('endTime', null),
    );

    await tester.ensureVisible(find.text('SAVE TRAINING'));
    await tester.tap(find.text('SAVE TRAINING'));
    await tester.pumpAndSettle();

    expect(
      database.rawRecord(IndexedDbStoreNames.activeTrainingDrafts, draftId),
      isNull,
    );
    expect(
      await database.findAll(IndexedDbStoreNames.trainingRecords),
      hasLength(1),
    );
    final savedEnvelope = (await database.findAll(
      IndexedDbStoreNames.trainingRecords,
    )).single;
    expect(savedEnvelope, containsPair('recordVersion', 2));
    expect(
      savedEnvelope['data'],
      allOf(
        containsPair('startTime', isNotNull),
        containsPair('endTime', isNotNull),
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(
      tester,
      database: database,
      activeTrainingDraftRepository: drafts,
    );
    expect(
      _trainingTheme(tester, active: false).colorScheme.primary,
      AppColors.primary,
    );
  });

  testWidgets('plan-only draft reloads without starting the session', (
    tester,
  ) async {
    final database = FakeIndexedDbDatabase();
    final drafts = IndexedDbActiveTrainingDraftRepository(database);
    await drafts.save(
      ActiveTrainingDraft(
        operationDate: '2026-07-31',
        entryState: const {
          'sessionName': '',
          'sessionMemo': '',
          'overallEvaluation': '',
          'sessionGrade': null,
          'dynamicStretchCompleted': null,
          'cooldownStretchCompleted': null,
          'planMetadata': {
            'exchangeId': 'training-plan-response-1',
            'sourceDigest':
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'sourceRecordId': 'training:2026-07-30',
            'sourceOperationDate': '2026-07-30',
            'note': 'Plan note',
          },
          'exercises': [
            {
              'exerciseName': 'Squat',
              'equipment': null,
              'equipmentSelectionMade': true,
              'evaluation': '',
              'targetWeight': '',
              'targetReps': <String>[],
              'targetNotes': '',
              'sets': [
                {
                  'setType': 'main',
                  'weight': '80',
                  'reps': '8',
                  'rpe': null,
                  'rest': '90',
                  'plannedWeightKg': 80.0,
                  'targetMinReps': 8,
                  'targetMaxReps': 10,
                },
              ],
            },
          ],
          'cardioEntries': <Object?>[],
        },
      ),
    );

    await _pump(
      tester,
      database: database,
      activeTrainingDraftRepository: drafts,
    );

    expect(find.text('PLAN READY'), findsOneWidget);
    expect(find.text('REFERENCE  2026-07-30'), findsOneWidget);
    expect(find.text('PLAN  80 kg'), findsOneWidget);
    expect(find.text('TARGET  8–10'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('v2-set-0-weight')))
          .controller!
          .text,
      '80',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('v2-set-0-reps')))
          .controller!
          .text,
      '8',
    );
    final weightAdjustments = find.byKey(
      const Key('v2-set-0-weight-adjustments'),
    );
    final repsAdjustments = find.byKey(const Key('v2-set-0-reps-adjustments'));
    await tester.tap(
      find.descendant(of: weightAdjustments, matching: find.text('+2.5')),
    );
    await tester.tap(
      find.descendant(of: repsAdjustments, matching: find.text('+1')),
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('v2-set-0-weight')))
          .controller!
          .text,
      '82.5',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('v2-set-0-reps')))
          .controller!
          .text,
      '9',
    );
    expect(find.text('PLAN  80 kg'), findsOneWidget);
    expect(find.text('TARGET  8–10'), findsOneWidget);
    expect(find.text('ACTIVE'), findsNothing);
    expect(find.text('ELAPSED'), findsNothing);
    expect(
      _trainingTheme(tester, active: false).colorScheme.primary,
      AppColors.primary,
    );

    await tester.tap(find.text('START TRAINING'));
    await tester.pump();

    expect(find.text('ACTIVE'), findsWidgets);
    expect(
      _trainingTheme(tester, active: true).colorScheme.primary,
      AppColors.success,
    );
    final restored = await drafts.findByOperationDate('2026-07-31');
    expect(restored?.startTime, isNotNull);
  });

  testWidgets('failed formal save preserves the Active Training Draft', (
    tester,
  ) async {
    final database = FakeIndexedDbDatabase();
    final drafts = IndexedDbActiveTrainingDraftRepository(database);
    await _pump(
      tester,
      database: database,
      activeTrainingDraftRepository: drafts,
    );
    await tester.tap(find.text('START TRAINING'));
    await tester.pump();
    _setExercise(tester, 'Squat');
    await tester.enterText(find.widgetWithText(TextField, 'WEIGHT'), '80');
    await tester.enterText(find.widgetWithText(TextField, 'REPS'), '5');
    database.failNextPutForStore = IndexedDbStoreNames.trainingRecords;

    await tester.ensureVisible(find.text('SAVE TRAINING'));
    await tester.tap(find.text('SAVE TRAINING'));
    await tester.pump();

    expect(
      await database.findAll(IndexedDbStoreNames.activeTrainingDrafts),
      hasLength(1),
    );
    expect(
      await database.findAll(IndexedDbStoreNames.trainingRecords),
      isEmpty,
    );
  });

  testWidgets('inactive UI is normal and discard clears draft and timer', (
    tester,
  ) async {
    final database = FakeIndexedDbDatabase();
    final drafts = IndexedDbActiveTrainingDraftRepository(database);
    await _pump(
      tester,
      database: database,
      activeTrainingDraftRepository: drafts,
    );
    expect(find.text('ACTIVE'), findsNothing);
    expect(find.text('PAUSED'), findsNothing);
    expect(
      _trainingTheme(tester, active: false).colorScheme.primary,
      AppColors.primary,
    );

    await tester.tap(find.text('START TRAINING'));
    await tester.pump();
    expect(find.text('ACTIVE'), findsWidgets);
    expect(
      _trainingTheme(tester, active: true).colorScheme.primary,
      AppColors.success,
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DISCARD SESSION'));
    await tester.pumpAndSettle();
    expect(find.text('トレーニングセッションを破棄しますか？'), findsOneWidget);
    await tester.tap(find.text('破棄'));
    await tester.pumpAndSettle();

    expect(
      await database.findAll(IndexedDbStoreNames.activeTrainingDrafts),
      isEmpty,
    );
    expect(find.text('ACTIVE'), findsNothing);
    expect(find.text('PAUSED'), findsNothing);
    expect(find.text('START TRAINING'), findsOneWidget);
    expect(
      _trainingTheme(tester, active: false).colorScheme.primary,
      AppColors.primary,
    );
  });

  testWidgets('active recording colors session exercise set and cardio cards', (
    tester,
  ) async {
    await _pump(tester, width: 390);
    final normalTheme = _trainingTheme(tester, active: false);
    expect(normalTheme.colorScheme.primary, AppColors.primary);
    expect(
      _cardColor(tester, const ValueKey('training-session-card')),
      normalTheme.cardColor,
    );

    await tester.tap(find.text('START TRAINING'));
    await tester.pump();
    final activeTheme = _trainingTheme(tester, active: true);
    expect(activeTheme.colorScheme.primary, AppColors.success);
    expect(activeTheme.colorScheme.error, normalTheme.colorScheme.error);
    expect(
      _cardColor(tester, const ValueKey('training-session-card')),
      activeTheme.cardColor,
    );
    expect(
      _cardColor(tester, const ValueKey('training-exercise-card-0')),
      activeTheme.cardColor,
    );
    final setDecoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byKey(const ValueKey('training-set-card-0')),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(setDecoration.color, AppColors.success.withValues(alpha: 0.04));
    expect(
      (setDecoration.border! as Border).top.color,
      activeTheme.colorScheme.outlineVariant,
    );

    await tester.ensureVisible(find.text('ADD EXERCISE'));
    await tester.tap(find.text('ADD EXERCISE'));
    await tester.pump();
    expect(
      _cardColor(tester, const ValueKey('training-exercise-card-1')),
      activeTheme.cardColor,
    );

    await tester.ensureVisible(find.text('ADD CARDIO'));
    await tester.tap(find.text('ADD CARDIO'));
    await tester.pump();
    expect(
      _cardColor(tester, const ValueKey('training-cardio-card-0')),
      activeTheme.cardColor,
    );

    await tester.ensureVisible(find.text('PAUSE TRAINING'));
    await tester.tap(find.text('PAUSE TRAINING'));
    await tester.pump();
    expect(find.text('PAUSED'), findsWidgets);
    expect(
      tester
          .widget<Theme>(find.byKey(const ValueKey('training-amber-base')))
          .data
          .colorScheme
          .primary,
      AppColors.warning,
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[320, 390, 900]) {
    testWidgets('active training base has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      await _pump(tester, width: width, disableAnimations: false);
      await tester.tap(find.text('START TRAINING'));
      await tester.pump(const Duration(milliseconds: 210));

      expect(
        _trainingTheme(tester, active: true).colorScheme.primary,
        AppColors.success,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('built-in equipment display keeps stable saved identity', (
    tester,
  ) async {
    final database = await _pump(tester);
    _setExercise(tester, 'BenchPress');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-exercise-0-equipment')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('パワーラック'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'WEIGHT'), '80');
    await tester.enterText(find.widgetWithText(TextField, 'REPS'), '5');

    await tester.tap(find.text('SAVE TRAINING'));
    await tester.pumpAndSettle();

    final records = await database.findAll(IndexedDbStoreNames.trainingRecords);
    final data = records.single['data'] as Map<String, dynamic>;
    final exercise = (data['exercises'] as List).single as Map<String, dynamic>;
    expect(exercise['equipment'], containsPair('catalogId', 'power_rack'));
    expect(exercise['equipment'], containsPair('name', 'Power Rack'));
  });

  testWidgets('cardio preview uses same-date STATUS without calories input', (
    tester,
  ) async {
    final now = DateTime.now();
    const localDate = '2026-07-31';
    final database = FakeIndexedDbDatabase();
    final status = PersistedStatusRecord(
      id: PersistedStatusRecord.canonicalId(localDate),
      localDate: localDate,
      createdAt: now.toUtc(),
      updatedAt: now.toUtc(),
      canonicalDate: localDate,
      recordKind: StatusRecordKind.canonical,
      data: MorningData(
        date: '${localDate}T07:00:00',
        weight: 96.8,
        bodyFat: 20,
        sleepHours: 7,
        sleepScore: 80,
        footPain: 0,
        workType: WorkType.work,
        workStart: '09:00',
        workEnd: '18:00',
        workBreak: '01:00',
        workHours: 8,
        memo: '',
      ),
    );
    database.seed(
      IndexedDbStoreNames.statusRecords,
      status.id,
      status.toRecord(),
    );
    await _pump(tester, database: database);

    await tester.tap(find.text('ADD CARDIO'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextField, '時間'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cardio-duration-minutes')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('05').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('APPLY'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'METs'), '4');
    await tester.pump();

    expect(find.text('34 kcal'), findsOneWidget);
    expect(
      find.text('Calculated from METs, duration, and STATUS weight'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, '推定消費カロリー'), findsNothing);
  });
}

void _expectAdjustmentGrid(
  WidgetTester tester, {
  required Finder grid,
  required List<String> labels,
}) {
  final buttons = find.descendant(
    of: grid,
    matching: find.byType(OutlinedButton),
  );
  expect(buttons, findsNWidgets(6));
  final rowTops = <double>[];

  for (final label in labels) {
    final button = find.descendant(
      of: grid,
      matching: find.widgetWithText(OutlinedButton, label),
    );
    expect(button, findsOneWidget);
    final rect = tester.getRect(button);
    expect(rect.height, greaterThanOrEqualTo(38));
    rowTops.add(rect.top);

    final outlined = tester.widget<OutlinedButton>(button);
    final shape = outlined.style!.shape!.resolve({});
    expect(shape, isA<RoundedRectangleBorder>());
    final radius = (shape! as RoundedRectangleBorder).borderRadius
        .resolve(TextDirection.ltr)
        .topLeft
        .x;
    expect(radius, lessThan(rect.height / 2));
  }

  expect(rowTops.toSet(), hasLength(2));
  expect(rowTops.where((top) => top == rowTops.first), hasLength(3));
}

void _setExercise(WidgetTester tester, String name) {
  tester
          .widget<ExerciseSelector>(find.byType(ExerciseSelector))
          .controller
          .text =
      name;
}

Future<FakeIndexedDbDatabase> _pump(
  WidgetTester tester, {
  double width = 900,
  Brightness brightness = Brightness.light,
  TrainingRecordReadModel? existingRecord,
  FakeIndexedDbDatabase? database,
  ActiveTrainingDraftRepository? activeTrainingDraftRepository,
  bool disableAnimations = true,
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final initialization = AppInitializationController()..markReady();
  AppRepositoryRegistry.beginStartup(controller: initialization);
  final targetDatabase = database ?? FakeIndexedDbDatabase();
  seedOperationState(targetDatabase, '2026-07-31');
  AppRepositoryRegistry.install(
    AppRepositoryContainer.indexedDb(targetDatabase),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? ThemeData.dark()
          : ThemeData.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: TrainingEntryPage(
        existingRecord: existingRecord,
        activeTrainingDraftRepository: activeTrainingDraftRepository,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  return targetDatabase;
}

ThemeData _trainingTheme(WidgetTester tester, {required bool active}) => tester
    .widget<Theme>(
      find.byKey(
        ValueKey(active ? 'training-green-base' : 'training-blue-base'),
      ),
    )
    .data;

Color _cardColor(WidgetTester tester, Key operationCardKey) => tester
    .widget<Card>(
      find.descendant(
        of: find.byKey(operationCardKey),
        matching: find.byType(Card),
      ),
    )
    .color!;
