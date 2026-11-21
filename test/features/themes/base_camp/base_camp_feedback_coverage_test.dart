import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'BASE CAMP operation feedback has no direct legacy transient surface',
    () {
      final lib = Directory('lib');
      final dartFiles = lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();

      final legacyTransientFiles = <String>[];
      var noticeCalls = 0;
      var confirmationCalls = 0;
      var panelConstructions = 0;
      var popupConstructions = 0;

      for (final file in dartFiles) {
        final normalized = file.path.replaceAll('\\', '/');
        final source = file.readAsStringSync();
        noticeCalls += _occurrences(source, 'showBaseCampOperationNotice(');
        confirmationCalls += _occurrences(
          source,
          'showBaseCampOperationConfirmation(',
        );
        panelConstructions += _occurrences(source, 'BaseCampOperationPanel(');
        popupConstructions += _occurrences(source, 'BaseCampTerminalPopup(');

        final ownsSharedSnackBarLifecycle =
            normalized.endsWith(
              'features/themes/base_camp/widgets/base_camp_operation_panel.dart',
            ) ||
            normalized.endsWith(
              'features/food/widgets/food_saved_floating_hud.dart',
            );
        if (!ownsSharedSnackBarLifecycle &&
            (source.contains('showSnackBar(') ||
                RegExp(r'(?<![A-Za-z])SnackBar\(').hasMatch(source))) {
          legacyTransientFiles.add(normalized);
        }
      }

      expect(legacyTransientFiles, isEmpty);
      expect(noticeCalls, greaterThanOrEqualTo(48));
      expect(confirmationCalls, greaterThanOrEqualTo(28));
      expect(panelConstructions, greaterThanOrEqualTo(10));
      expect(popupConstructions, greaterThanOrEqualTo(15));
    },
  );

  test('critical operation paths route through the terminal family', () {
    const requiredRouting = <String, List<String>>{
      'lib/features/food/widgets/food_saved_floating_hud.dart': <String>[
        'BaseCampTerminalNotice(',
      ],
      'lib/features/report_sync/pages/report_sync_exchange_page.dart': <String>[
        'BaseCampOperationPanel(',
      ],
      'lib/features/dashboard/widgets/base_camp_finalize_day_dialog.dart':
          <String>['BaseCampOperationPanel('],
      'lib/features/dashboard/widgets/backup_prompt_dialog.dart': <String>[
        'BaseCampOperationPanel(',
      ],
      'lib/features/morning/morning_fact_page.dart': <String>[
        'BaseCampOperationPanel(',
      ],
      'lib/features/activity/activity_entry_page.dart': <String>[
        'showBaseCampOperationNotice(',
        'showBaseCampOperationConfirmation(',
      ],
      'lib/features/training/training_entry_page.dart': <String>[
        'showBaseCampOperationNotice(',
        'showBaseCampOperationConfirmation(',
      ],
      'lib/features/system/pages/system_page.dart': <String>[
        'showBaseCampOperationNotice(',
        'BaseCampTerminalPopup(',
      ],
      'lib/features/food/widgets/food_ocr_scanner.dart': <String>[
        'BaseCampOperationPanel(',
        'BaseCampTerminalPopup(',
        'BaseCampTerminalPopupButton(',
      ],
      'lib/features/import_export/backup_restore_page.dart': <String>[
        'showBaseCampOperationConfirmation(',
      ],
      'lib/features/themes/base_camp/base_camp_map_editor_page.dart': <String>[
        'showBaseCampOperationNotice(',
        'showBaseCampOperationConfirmation(',
        'BaseCampTerminalPopup(',
      ],
      'lib/features/themes/base_camp/soldier_live_motion_preview_page.dart':
          <String>['showBaseCampOperationNotice(', 'BaseCampTerminalPopup('],
    };

    for (final entry in requiredRouting.entries) {
      final source = File(entry.key).readAsStringSync();
      for (final token in entry.value) {
        expect(source, contains(token), reason: '${entry.key} must use $token');
      }
    }
  });
}

int _occurrences(String source, String token) =>
    token.allMatches(source).length;
