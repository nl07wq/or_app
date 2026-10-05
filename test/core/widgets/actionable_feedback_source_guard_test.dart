import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _rawControls = <String>[
  'IconButton',
  'TextButton',
  'OutlinedButton',
  'ElevatedButton',
  'FilledButton',
  'FloatingActionButton',
  'PopupMenuButton',
  'PopupMenuItem',
  'BackButton',
  'ListTile',
  'InkWell',
  'GestureDetector',
];

const _sharedPrimitiveInternals = <String>{
  'lib/core/widgets/operation_button.dart',
  'lib/core/widgets/operation_card.dart',
  'lib/core/widgets/operation_text_field.dart',
  'lib/core/widgets/operation_dropdown.dart',
};

const _rawInputControls = <String>[
  'TextField',
  'TextFormField',
  'DropdownButtonFormField',
  'DropdownButton',
  'SwitchListTile',
  'CheckboxListTile',
  'Checkbox',
  'Slider',
  'ChoiceChip',
  'FilterChip',
  'SegmentedButton',
];

// Developer-only visual laboratories deliberately use raw Material controls to
// inspect framework rendering. They are not production editable surfaces;
// keeping the exception list explicit prevents them from weakening the guard
// for any shipped feature module.
const _inputTechnicalExceptions = <String>{
  'lib/features/system/pages/animations_sandbox_page.dart',
  'lib/features/system/pages/body_map_svg_preview_page.dart',
  'lib/features/system/pages/fox_pattern_preview.dart',
  'lib/features/system/pages/fox_rear_leg_geometry_lab.dart',
  'lib/features/system/pages/fox_run_v1_section.dart',
  'lib/features/system/pages/pixel_lab_page.dart',
};

void main() {
  test('app actionable controls declare V2.4 ownership', () {
    final gaps = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('.dart') &&
              !file.path.endsWith('global_touch_ripple.dart'),
        );
    for (final file in files) {
      final normalizedPath = file.path.replaceAll('\\', '/');
      final source = file.readAsStringSync();
      for (final name in _rawControls) {
        final pattern = RegExp(
          '\\b$name(?:<[^>]+>)?(?:\\.(?:icon|extended))?\\s*\\(',
        );
        for (final match in pattern.allMatches(source)) {
          final prefix = source.substring(0, match.start);
          if (RegExp(r'const\s*$').hasMatch(prefix)) continue;
          final open = source.indexOf('(', match.start);
          final close = _matchingParen(source, open);
          if (close == null) {
            gaps.add('${file.path}:${_lineOf(source, match.start)} $name');
            continue;
          }
          final constructor = source.substring(open, close + 1);
          if (_sharedPrimitiveInternals.contains(normalizedPath)) continue;
          if ((name == 'GestureDetector' || name == 'InkWell') &&
              !RegExp(
                r'on(?:Tap|DoubleTap|LongPress)\s*:',
              ).hasMatch(constructor)) {
            // Drag, scale, hover, and scroll gesture infrastructure is not a
            // discrete actionable control and must retain passive feedback.
            continue;
          }
          if (name == 'ListTile' &&
              !RegExp(r'on(?:Tap|LongPress)\s*:').hasMatch(constructor)) {
            // Display-only list rows are passive by design.
            continue;
          }
          if (RegExp(r'onPressed\s*:\s*null').hasMatch(constructor)) {
            // A fully disabled stock button receives no pointer action and is
            // intentionally outside the pointer-aware unavailable grammar.
            continue;
          }
          if ((name == 'PopupMenuButton' || name == 'PopupMenuItem') &&
              RegExp(r'enabled\s*:\s*false').hasMatch(constructor)) {
            // Disabled menu surfaces are non-actionable framework content.
            continue;
          }
          final tail = source.substring(close + 1);
          if (RegExp(r'^\s*\.actionableFeedback\s*\(').hasMatch(tail) ||
              RegExp(r'^\s*\.inputFeedback\s*\(').hasMatch(tail) ||
              _insideOwnershipRegion(source, match.start)) {
            continue;
          }
          gaps.add('${file.path}:${_lineOf(source, match.start)} $name');
        }
      }
    }
    expect(
      gaps,
      isEmpty,
      reason:
          'Raw actionable controls must call actionableFeedback() or be inside '
          'ActionableFeedbackButton/ActionableFeedbackRegion:\n${gaps.join('\n')}',
    );
  });

  test('app input controls declare the shared silent input domain', () {
    final gaps = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('.dart') &&
              !file.path.endsWith('global_touch_ripple.dart'),
        );
    for (final file in files) {
      final normalizedPath = file.path.replaceAll('\\', '/');
      if (_inputTechnicalExceptions.contains(normalizedPath)) continue;
      final source = file.readAsStringSync();
      for (final name in _rawInputControls) {
        final pattern = RegExp('\\b$name(?:<[^>]+>)?\\s*\\(');
        for (final match in pattern.allMatches(source)) {
          final prefix = source.substring(0, match.start);
          if (RegExp(r'const\s*$').hasMatch(prefix)) continue;
          final open = source.indexOf('(', match.start);
          final close = _matchingParen(source, open);
          if (close == null) {
            gaps.add('${file.path}:${_lineOf(source, match.start)} $name');
            continue;
          }
          if (_sharedPrimitiveInternals.contains(normalizedPath)) continue;
          final constructor = source.substring(open, close + 1);
          if (RegExp(
            r'on(?:Changed|Selected)\s*:\s*null',
          ).hasMatch(constructor)) {
            continue;
          }
          final tail = source.substring(close + 1);
          if (RegExp(
                r'^\s*\.(?:inputFeedback|actionableFeedback)\s*\(',
              ).hasMatch(tail) ||
              _insideInputRegion(source, match.start) ||
              _insideOwnershipRegion(source, match.start)) {
            continue;
          }
          gaps.add('${file.path}:${_lineOf(source, match.start)} $name');
        }
      }
    }
    expect(
      gaps,
      isEmpty,
      reason:
          'Raw editable/selectable controls must call inputFeedback() or be '
          'inside InputFeedbackRegion:\n${gaps.join('\n')}',
    );
  });
}

bool _insideOwnershipRegion(String source, int offset) {
  for (final marker in [
    'ActionableFeedbackButton(',
    'ActionableFeedbackRegion(',
  ]) {
    var start = source.lastIndexOf(marker, offset);
    while (start >= 0) {
      final open = source.indexOf('(', start);
      final close = _matchingParen(source, open);
      if (close != null && close >= offset) return true;
      start = source.lastIndexOf(marker, start - 1);
    }
  }
  return false;
}

bool _insideInputRegion(String source, int offset) {
  var start = source.lastIndexOf('InputFeedbackRegion(', offset);
  while (start >= 0) {
    final open = source.indexOf('(', start);
    final close = _matchingParen(source, open);
    if (close != null && close >= offset) return true;
    start = source.lastIndexOf('InputFeedbackRegion(', start - 1);
  }
  return false;
}

int _lineOf(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;

int? _matchingParen(String source, int open) {
  var depth = 0;
  var quote = 0;
  var lineComment = false;
  var blockComment = false;
  for (var index = open; index < source.length; index++) {
    final code = source.codeUnitAt(index);
    final next = index + 1 < source.length ? source.codeUnitAt(index + 1) : 0;
    if (lineComment) {
      if (code == 10) lineComment = false;
      continue;
    }
    if (blockComment) {
      if (code == 42 && next == 47) {
        blockComment = false;
        index++;
      }
      continue;
    }
    if (quote != 0) {
      if (code == 92) {
        index++;
      } else if (code == quote) {
        quote = 0;
      }
      continue;
    }
    if (code == 47 && next == 47) {
      lineComment = true;
      index++;
    } else if (code == 47 && next == 42) {
      blockComment = true;
      index++;
    } else if (code == 39 || code == 34) {
      quote = code;
    } else if (code == 40) {
      depth++;
    } else if (code == 41 && --depth == 0) {
      return index;
    }
  }
  return null;
}
