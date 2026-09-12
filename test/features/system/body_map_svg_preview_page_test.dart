import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/body_map_svg_preview_page.dart';
import 'package:or_app/features/training/services/training_history_domain_service.dart';

void main() {
  testWidgets('full preview sequence clears stale selection safely', (
    tester,
  ) async {
    await _pump(tester, 390);
    await _tapRegion(tester, 'svg-body-map-front', 75, 112);
    expect(find.text('SELECTED: CHEST'), findsOneWidget);
    await _tapRegion(tester, 'svg-body-map-front', 100, 150);
    expect(find.text('SELECTED: CORE'), findsOneWidget);
    await _tapRegion(tester, 'svg-body-map-front', 82, 220);
    expect(find.text('SELECTED: QUADRICEPS'), findsOneWidget);

    await _setRecovery(tester, '回復中');
    await _setSupport(tester, true);
    expect(tester.takeException(), isNull);

    await _scrollToTop(tester);
    await tester.tap(find.text('背面'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('svg-body-map-back')), findsOneWidget);
    expect(find.text('TAP A MUSCLE REGION'), findsOneWidget);

    await _tapRegion(tester, 'svg-body-map-back', 80, 130);
    expect(find.text('SELECTED: LATS'), findsOneWidget);
    await _tapRegion(tester, 'svg-body-map-back', 100, 90);
    expect(find.text('SELECTED: TRAPEZIUS'), findsOneWidget);
    await _tapRegion(tester, 'svg-body-map-back', 80, 175);
    expect(find.text('SELECTED: GLUTES'), findsOneWidget);
    await _tapRegion(tester, 'svg-body-map-back', 82, 220);
    expect(find.text('SELECTED: HAMSTRINGS'), findsOneWidget);
    await _tapRegion(tester, 'svg-body-map-back', 82, 285);
    expect(find.text('SELECTED: CALVES'), findsOneWidget);
    await _tapRegion(tester, 'svg-body-map-back', 80, 130);
    expect(find.text('SELECTED: LATS'), findsOneWidget);
    await _setRecovery(tester, '回復目安に接近');
    await _setSupport(tester, false);
    await _scrollToTop(tester);
    await tester.tap(find.text('前面'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('svg-body-map-front')), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final width in [320.0, 390.0, 900.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpAndSettle();
      expect(find.text('BODY MAP SVG PREVIEW'), findsOneWidget);
      await _scrollToBottom(tester);
      expect(
        find.byType(DropdownButtonFormField<RecoveryStatus>),
        findsOneWidget,
      );
      expect(find.text('SUPPORT OUTLINE PREVIEW'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pump(WidgetTester tester, double width) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MaterialApp(home: BodyMapSvgPreviewPage()));
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
  await _scrollToTop(tester);
  expect(find.text('BODY MAP SVG PREVIEW'), findsOneWidget);
  expect(
    find.byKey(const ValueKey('svg-body-map-front'), skipOffstage: false),
    findsOneWidget,
  );
}

Future<void> _tapRegion(
  WidgetTester tester,
  String key,
  double x,
  double y,
) async {
  final target = find.byKey(ValueKey(key), skipOffstage: false);
  await tester.ensureVisible(target);
  final box = tester.getRect(target);
  await tester.tapAt(
    Offset(box.left + box.width * x / 200, box.top + box.height * y / 340),
  );
  await tester.pumpAndSettle();
}

Future<void> _setRecovery(WidgetTester tester, String label) async {
  await _scrollToBottom(tester);
  final fixture = find.byType(DropdownButtonFormField<RecoveryStatus>);
  await tester.ensureVisible(fixture);
  await tester.tap(fixture);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _setSupport(WidgetTester tester, bool value) async {
  await _scrollToBottom(tester);
  final control = find.text('SUPPORT OUTLINE PREVIEW');
  await tester.ensureVisible(control);
  final tile = tester.widget<SwitchListTile>(
    find.ancestor(of: control, matching: find.byType(SwitchListTile)),
  );
  if (tile.value != value) {
    await tester.tap(control);
    await tester.pumpAndSettle();
  }
}

Future<void> _scrollToTop(WidgetTester tester) async {
  await tester.fling(find.byType(ListView), const Offset(0, 800), 1000);
  await tester.pumpAndSettle();
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.fling(find.byType(ListView), const Offset(0, -800), 1000);
  await tester.pumpAndSettle();
}
