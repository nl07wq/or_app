import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:or_app/core/widgets/operation_text_field.dart';
import 'package:or_app/features/themes/base_camp/base_camp_retro_theme.dart';

void main() {
  late String indexHtml;

  setUpAll(() {
    indexHtml = File('web/index.html').readAsStringSync();
  });

  test('viewport preserves user zoom and uses the device width', () {
    final viewport = RegExp(
      r'<meta\s+name="viewport"\s+content="([^"]+)"',
    ).firstMatch(indexHtml);

    expect(viewport, isNotNull);
    expect(viewport!.group(1), contains('width=device-width'));
    expect(viewport.group(1), contains('initial-scale=1.0'));
    expect(viewport.group(1), isNot(contains('maximum-scale')));
    expect(viewport.group(1), isNot(contains('user-scalable=no')));
  });

  test('only Flutter text-editing controls receive the iOS font floor', () {
    expect(
      indexHtml,
      contains('flutter-view flt-text-editing-host input.flt-text-editing,'),
    );
    expect(
      indexHtml,
      contains('flutter-view flt-text-editing-host textarea.flt-text-editing'),
    );
    expect(
      indexHtml,
      contains(
        'flutter-view flt-semantics-host input[data-semantics-role="text-field"]',
      ),
    );
    expect(
      indexHtml,
      contains(
        'flutter-view flt-semantics-host textarea[data-semantics-role="text-field"]',
      ),
    );
    expect(indexHtml, contains('font-size: 16px !important;'));

    // A document-wide input rule would also modify file pickers and any
    // future non-Flutter controls. Keep this compatibility layer scoped to
    // the engine host that owns active EditableText elements.
    expect(indexHtml, isNot(contains('\n    input, textarea {')));
  });

  testWidgets('compatibility layer does not enlarge visible BASE CAMP text', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'VISIBLE TYPOGRAPHY');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: BaseCampRetroTheme.apply(ThemeData.dark()),
        home: Scaffold(
          body: OperationTextField(controller: controller, label: 'NAME'),
        ),
      ),
    );

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.style.fontSize, 12);
    expect(editable.style.fontFamily, baseCampPixelFontFamily);
  });
}
