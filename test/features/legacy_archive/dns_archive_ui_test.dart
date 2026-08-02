import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/import_export/services/backup_file_gateway.dart';
import 'package:or_app/features/legacy_archive/models/dns_archive_models.dart';
import 'package:or_app/features/legacy_archive/pages/dns_archive_import_page.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  testWidgets(
    'DNS UI generates source, previews normalized JSON, and imports',
    (tester) async {
      tester.view.physicalSize = const Size(390, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = AppRepositoryContainer.indexedDb(
        FakeIndexedDbDatabase(),
      );
      final copied = <String>[];
      final files = _FakeFileGateway();
      await tester.pumpWidget(
        MaterialApp(
          home: DnsArchiveImportPage(
            container: container,
            fileGateway: files,
            clipboardWriter: (value) async => copied.add(value),
            clock: () => DateTime.utc(2026, 8, 2, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('dns-source-input')),
          matching: find.byType(TextField),
        ),
        'DNS-2025-01-01\nWeight: 70',
      );
      await tester.tap(find.text('GENERATE DNS SOURCE JSON'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Source Records  1'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('COPY DNS CONVERSION INSTRUCTION'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('COPY DNS CONVERSION INSTRUCTION'));
      await tester.pump();
      await tester.tap(find.text('COPY DNS SOURCE JSON'));
      await tester.pump();
      expect(copied, hasLength(2));
      expect(copied.first, contains('JSON only'));

      final source = container.dnsSourceCodec.decode(copied.last);
      final normalized = DnsNormalizedPackage(
        sourcePackageId: source.sourcePackageId,
        generatedAt: DateTime.utc(2026, 8, 2, 12),
        records: [
          DnsNormalizedRecord(
            sourceRecordId: source.records.single.sourceRecordId,
            operationDate: '2025-01-01',
            parseStatus: DnsParseStatus.parsed,
            data: const {
              'body': null,
              'nutrition': null,
              'hydration': null,
              'activity': null,
              'work': null,
              'operation': null,
            },
            warnings: const [],
            unmappedFragments: const [],
          ),
        ],
      );
      files.selected = BackupSelectedFile(
        name: 'dns-normalized-${source.sourcePackageId}.json',
        bytes: container.dnsNormalizedCodec.encode(normalized).codeUnits,
      );
      await tester.scrollUntilVisible(
        find.text('SELECT DNS NORMALIZED FILE'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('SELECT DNS NORMALIZED FILE'));
      await tester.pumpAndSettle();
      expect(find.text('DNS NORMALIZED FILE LOADED'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('VALIDATE'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('VALIDATE'));
      await tester.pumpAndSettle();
      expect(find.text('PREVIEW'), findsOneWidget);
      expect(find.text('CREATE  1'), findsOneWidget);
      expect(find.text('IMPORT ARCHIVE'), findsOneWidget);

      await tester.tap(find.text('IMPORT ARCHIVE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONFIRM IMPORT'));
      await tester.pumpAndSettle();
      expect(find.text('COMPLETE · READ-BACK VERIFIED'), findsOneWidget);
      expect(await container.legacyDailySummaries.list(), hasLength(1));
      expect(find.text('2025-01-01'), findsOneWidget);
      expect(find.textContaining('Weight: 70'), findsNothing);
    },
  );

  for (final width in [320.0, 390.0, 900.0, 1280.0]) {
    testWidgets('DNS UI has no overflow at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: DnsArchiveImportPage(
              container: AppRepositoryContainer.indexedDb(
                FakeIndexedDbDatabase(),
              ),
              fileGateway: _FakeFileGateway(),
              clipboardWriter: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}

class _FakeFileGateway implements BackupFileGateway {
  BackupSelectedFile? selected;

  @override
  String? get origin => 'https://example.test';

  @override
  Future<BackupFileDelivery> shareOrSave({
    required String fileName,
    required String content,
  }) async => BackupFileDelivery.downloaded;

  @override
  Future<BackupSelectedFile?> selectJson() async => selected;
}
