import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test(
    'STATUS route family uses the production ambient behind transparent headers',
    () {
      final ambient = source(
        'lib/features/morning/widgets/status_radial_spectrum_ambient.dart',
      );
      expect(ambient, contains('class StatusAmbientBackground'));

      for (final path in const [
        'lib/features/morning/morning_page.dart',
        'lib/features/morning/morning_history_page.dart',
        'lib/features/morning/morning_fact_page.dart',
      ]) {
        final page = source(path);
        expect(page, contains('AmbientPageScaffold'));
        expect(page, contains('StatusAmbientBackground'));
        expect(page, contains('forceMaterialTransparency: true'));
        expect(page, contains('elevation: 0'));
      }
    },
  );

  test(
    'ACTIVITY route family uses its own production ambient and glass surfaces',
    () {
      final ambient = source(
        'lib/features/activity/widgets/activity_ambient_kinetic_field.dart',
      );
      expect(ambient, contains('class ActivityAmbientBackground'));

      for (final path in const [
        'lib/features/activity/activity_page.dart',
        'lib/features/activity/activity_history_page.dart',
        'lib/features/activity/activity_entry_page.dart',
      ]) {
        final page = source(path);
        expect(page, contains('AmbientPageScaffold'));
        expect(page, contains('ActivityAmbientBackground'));
        expect(page, contains('forceMaterialTransparency: true'));
        expect(page, contains('elevation: 0'));
      }

      expect(
        source('lib/features/activity/widgets/bowel_card.dart'),
        contains('DashboardGlassCard'),
      );
      expect(
        source('lib/features/activity/widgets/digestive_event_card.dart'),
        contains('DashboardGlassCard'),
      );
      final entry = source('lib/features/activity/activity_entry_page.dart');
      expect(entry, contains('DashboardGlassCard.decoration'));
      expect(entry, contains('_activityGlassInputDecoration'));
      expect(entry, contains('backgroundColor: Colors.transparent'));
      expect(entry, contains('glass: true'));
    },
  );

  test('shared calendar retains CIRCUIT ambient for every caller context', () {
    final calendar = source('lib/features/schedule/pages/calendar_page.dart');
    final status = source('lib/features/morning/morning_page.dart');
    expect(calendar, contains('enum CalendarAmbientContext { status }'));
    expect(calendar, contains('HolographicAmbientBackground'));
    expect(calendar, isNot(contains('StatusAmbientBackground')));
    expect(
      RegExp('HolographicAmbientBackground').allMatches(calendar).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      calendar,
      contains('widget.ambientContext == CalendarAmbientContext.status'),
    );
    expect(status, contains('ambientContext: CalendarAmbientContext.status'));
  });

  test(
    'V1.2 ambient scaffold shares one extended Scaffold surface with its header',
    () {
      final scaffold = source('lib/core/widgets/ambient_page_scaffold.dart');
      expect(scaffold, contains('backgroundColor: Colors.transparent'));
      expect(scaffold, contains('body: Stack('));
      expect(
        scaffold,
        contains('Positioned.fill(child: ExcludeSemantics(child: ambient))'),
      );
      expect(scaffold, contains('extendBodyBehindAppBar: true'));
      expect(
        scaffold,
        isNot(contains('Widget build(BuildContext context) => Stack(')),
      );
    },
  );

  test(
    'glass input treatment is opt-in and does not affect unrelated inputs',
    () {
      final input = source('lib/core/widgets/operation_text_field.dart');
      expect(input, contains('final bool glass'));
      expect(input, contains('filled: glass'));
      expect(input, contains('this.glass = false'));
    },
  );
}
