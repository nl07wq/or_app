import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/notifications/models/notification_configuration.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/import_export/models/backup_package.dart';
import 'package:or_app/features/import_export/models/backup_audit_package.dart';
import 'package:or_app/features/import_export/services/backup_canonical_codec.dart';
import 'package:or_app/features/import_export/services/backup_export_service.dart';
import 'package:or_app/features/import_export/services/backup_import_service.dart';
import 'package:or_app/features/import_export/services/backup_package_codec.dart';
import 'package:or_app/features/import_export/services/backup_v14_transform.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/models/operation_state.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  test(
    'complete backup and restore round-trip app-local device settings',
    () async {
      final source = FakeIndexedDbDatabase();
      final timestamp = DateTime.utc(2026, 10, 6, 12);
      source.seed(
        IndexedDbStoreNames.operationState,
        OperationState.canonicalId,
        OperationState(
          operationDate: OperationLocalDate.parse('2026-10-06'),
          createdAt: timestamp,
          updatedAt: timestamp,
        ).toRecord(),
      );
      final original = DeviceSettingsController.instance.value;
      DeviceSettingsController.instance.resetForTesting(
        const DeviceSettings(
          masterVolume: .7,
          commandVolume: .6,
          exitVolume: .5,
          rejectedVolume: .4,
          ambientVolume: .3,
          brightness: .8,
          rippleEnabled: false,
          ambientCircuitEnabled: false,
          ambientWildlifeEnabled: false,
          notificationPrivacyMode: NotificationPrivacyMode.titleVisible,
          reducedMotion: ReducedMotionPreference.on,
        ),
      );
      try {
        final bundle = await BackupExportService(
          database: source,
          controller: AppInitializationController()..markReady(),
          clock: () => timestamp,
        ).createCurrentBundle();
        final decoded = const BackupPackageCodec().decode(
          BackupExportService.encode(bundle.normal),
        );
        expect(decoded.deviceSettings?['masterVolume'], .7);
        expect(decoded.deviceSettings?['ambientCircuitEnabled'], isFalse);
        expect(decoded.deviceSettings?['ambientWildlifeEnabled'], isFalse);
        expect(
          decoded.deviceSettings?['notificationPrivacyMode'],
          NotificationPrivacyMode.titleVisible.name,
        );

        Map<String, Object?>? restored;
        final target = FakeIndexedDbDatabase();
        final importer = BackupImportService(
          database: target,
          controller: AppInitializationController()..markReady(),
          restore: () async {},
          restoreDeviceSettings: (settings) async => restored = settings,
          deviceSettingsSnapshot: () => const DeviceSettings().toJson(),
        );
        final hydrated = BackupV14Transform.hydratePackage(
          bundle.normal,
          bundle.audit,
        );
        final result = await importer.execute(
          await importer.dryRun(hydrated, BackupImportMode.replaceAll),
        );

        expect(result.success, isTrue);
        expect(restored?['masterVolume'], .7);
        expect(restored?['reducedMotion'], 'on');

        final legacyPackage = BackupExportService.buildPackage(
          exportId: hydrated.exportId,
          exportedAt: hydrated.exportedAt,
          source: hydrated.source,
          data: bundle.normal.data,
          schemaVersion: 17,
          auditArchiveId: bundle.normal.auditArchiveId,
        );
        final legacy = const BackupPackageCodec().decode(
          BackupExportService.encode(legacyPackage),
        );
        final legacyAuditPayload = bundle.audit.toJson()
          ..['normalPackageDigest'] = legacy.digests.package
          ..['digests'] = bundle.audit.digests.sections;
        final legacyAudit = BackupAuditPackage(
          archiveId: bundle.audit.archiveId,
          normalExportId: bundle.audit.normalExportId,
          normalPackageDigest: legacy.digests.package,
          exportedAt: bundle.audit.exportedAt,
          source: bundle.audit.source,
          archiveComplete: bundle.audit.archiveComplete,
          digests: BackupDigests(
            package: BackupCanonicalCodec.digest(legacyAuditPayload),
            sections: bundle.audit.digests.sections,
          ),
          data: bundle.audit.data,
        );
        restored = null;
        final legacyResult = await importer.execute(
          await importer.dryRun(
            BackupV14Transform.hydratePackage(legacy, legacyAudit),
            BackupImportMode.replaceAll,
          ),
        );
        expect(legacyResult.success, isTrue);
        expect(restored, const DeviceSettings().toJson());

        restored = null;
        final mergeResult = await importer.execute(
          await importer.dryRun(hydrated, BackupImportMode.merge),
        );
        expect(mergeResult.success, isTrue);
        expect(restored, isNull);
      } finally {
        DeviceSettingsController.instance.resetForTesting(original);
      }
    },
  );
}
