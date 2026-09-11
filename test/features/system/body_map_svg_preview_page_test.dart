import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/body_map_svg_preview_page.dart';

void main() {
  testWidgets('preview supports SVG selection and fixture controls responsively', (tester) async {
    for (final width in [320.0, 390.0, 900.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(const MaterialApp(home: BodyMapSvgPreviewPage()));
      await tester.pumpAndSettle();
      expect(find.text('BODY MAP SVG PREVIEW'), findsOneWidget);
      expect(find.byKey(const ValueKey('svg-body-map-front')), findsOneWidget);
      await tester.tap(find.text('背面'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('svg-body-map-back')), findsOneWidget);
      final fixture = find.byKey(const ValueKey('body-map-recovery-fixture'));
      await tester.ensureVisible(fixture);
      await tester.tap(fixture);
      await tester.pumpAndSettle();
      await tester.tap(find.text('回復中').last);
      await tester.pumpAndSettle();
      final support = find.text('SUPPORT OUTLINE PREVIEW');
      await tester.ensureVisible(support);
      await tester.tap(support);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
