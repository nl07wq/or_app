import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/boot_presentation_session.dart';
import 'package:or_app/core/services/startup_entry_classifier.dart';

void main() {
  test('recent prior pagehide classifies a new document as short reentry', () {
    final now = DateTime(2026, 9, 4, 12);
    final classifier = StartupEntryClassifier(
      now: () => now,
      documentRunId: 'document-b',
    );
    classifier.recordPageHideForTesting(
      occurredAt: now.subtract(const Duration(milliseconds: 2500)),
      previousDocumentRunId: 'document-a',
    );

    final result = classifier.classifyAtDocumentStart();

    expect(result.classification, StartupEntryClassification.shortReentry);
    expect(result.previousPageHideAgeMs, 2500);
    final session = BootPresentationSession(startupEntryClassifier: classifier);
    expect(session.claimInitialBootPresentation(), isFalse);
    expect(session.lastClaimReason, 'shortReentry');
  });

  test('absent or expired pagehide marker preserves a fresh Boot claim', () {
    final now = DateTime(2026, 9, 4, 12);
    final absent = StartupEntryClassifier(now: () => now, documentRunId: 'b');
    expect(
      absent.classifyAtDocumentStart().classification,
      StartupEntryClassification.freshLaunch,
    );
    expect(
      BootPresentationSession(
        startupEntryClassifier: absent,
      ).claimInitialBootPresentation(),
      isTrue,
    );

    final expired = StartupEntryClassifier(now: () => now, documentRunId: 'b');
    expired.recordPageHideForTesting(
      occurredAt: now.subtract(
        StartupEntryClassifier.reentryWindow + const Duration(seconds: 1),
      ),
      previousDocumentRunId: 'a',
    );
    expect(
      expired.classifyAtDocumentStart().classification,
      StartupEntryClassification.freshLaunch,
    );
  });

  test('same-document lifecycle marker does not classify as reentry', () {
    final now = DateTime(2026, 9, 4, 12);
    final classifier = StartupEntryClassifier(
      now: () => now,
      documentRunId: 'same',
    );
    classifier.recordPageHideForTesting(
      occurredAt: now,
      previousDocumentRunId: 'same',
    );

    expect(
      classifier.classifyAtDocumentStart().classification,
      StartupEntryClassification.freshLaunch,
    );
  });
}
