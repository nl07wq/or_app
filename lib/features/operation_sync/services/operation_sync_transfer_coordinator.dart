import '../../import_export/services/backup_file_gateway.dart';
import '../../repositories/app_repository_container.dart';
import '../models/operation_sync_history.dart';
import '../models/operation_sync_preview.dart';
import '../models/operation_sync_state.dart';
import '../models/operation_transfer_package.dart';
import '../repository/operation_sync_history_repository.dart';
import '../repository/operation_sync_state_repository.dart';
import 'operation_sync_core_service.dart';
import 'operation_transfer_codec.dart';
import 'operation_transfer_export_service.dart';
import 'operation_transfer_id_generator.dart';

class OperationSyncWorkspace {
  final OperationSyncState state;
  final List<OperationSyncHistory> history;

  OperationSyncWorkspace({
    required this.state,
    required Iterable<OperationSyncHistory> history,
  }) : history = List.unmodifiable(history);
}

class OperationSyncExportOutcome {
  final OperationTransferPackage package;
  final String fileName;
  final BackupFileDelivery delivery;

  const OperationSyncExportOutcome({
    required this.package,
    required this.fileName,
    required this.delivery,
  });
}

class OperationSyncSelection {
  final String fileName;
  final int fileSize;
  final OperationTransferPackage package;
  final OperationSyncPreview preview;
  final bool isRecovery;

  const OperationSyncSelection({
    required this.fileName,
    required this.fileSize,
    required this.package,
    required this.preview,
    required this.isRecovery,
  });
}

abstract interface class OperationSyncWorkflow {
  Future<OperationSyncWorkspace> load();

  Future<OperationSyncExportOutcome> exportPackage();

  Future<OperationSyncSelection?> selectAndPreview();

  Future<void> apply(OperationSyncSelection selection);
}

class OperationSyncTransferCoordinator implements OperationSyncWorkflow {
  static const sourceApplicationVersion = '1.0.0';

  final OperationTransferExportService exportService;
  final OperationTransferCodec codec;
  final OperationSyncCoreService core;
  final OperationSyncStateRepository stateRepository;
  final OperationSyncHistoryRepository historyRepository;
  final BackupFileGateway _fileGateway;
  final OperationTransferIdGenerator _idGenerator;

  OperationSyncTransferCoordinator({
    required this.exportService,
    required this.codec,
    required this.core,
    required this.stateRepository,
    required this.historyRepository,
    BackupFileGateway? fileGateway,
    OperationTransferIdGenerator? idGenerator,
  }) : _fileGateway = fileGateway ?? BackupFileGateway.platform(),
       _idGenerator = idGenerator ?? OperationTransferIdGenerator();

  factory OperationSyncTransferCoordinator.production({
    BackupFileGateway? fileGateway,
  }) {
    final container = AppRepositoryRegistry.container;
    return OperationSyncTransferCoordinator(
      exportService: container.operationTransferExport,
      codec: container.operationTransferCodec,
      core: container.operationSyncCore,
      stateRepository: container.operationSyncState,
      historyRepository: container.operationSyncHistory,
      fileGateway: fileGateway,
    );
  }

  @override
  Future<OperationSyncWorkspace> load() async {
    final state = await stateRepository.initializeIfAbsent();
    return OperationSyncWorkspace(
      state: state,
      history: await historyRepository.list(),
    );
  }

  @override
  Future<OperationSyncExportOutcome> exportPackage() async {
    final package = await exportService.createPackage(
      packageId: _idGenerator.generate(),
      sourceApplicationVersion: sourceApplicationVersion,
    );
    final fileName = fileNameFor(package.createdAt.toLocal());
    final delivery = await _fileGateway.shareOrSave(
      fileName: fileName,
      content: codec.encode(package),
    );
    return OperationSyncExportOutcome(
      package: package,
      fileName: fileName,
      delivery: delivery,
    );
  }

  @override
  Future<OperationSyncSelection?> selectAndPreview() async {
    final file = await _fileGateway.selectJson();
    if (file == null) return null;
    final package = codec.decodeUtf8(file.bytes);
    final rawPackage = codec.encode(package);
    final state = await stateRepository.initializeIfAbsent();
    final history = state.operationId == null
        ? null
        : await historyRepository.readById(state.operationId!);
    final isRecovery =
        state.requiresRecovery ||
        state.phase == OperationSyncPhase.previewReady ||
        (state.phase == OperationSyncPhase.completed && history == null);
    final preview = isRecovery
        ? await core.resumePreview(rawPackage)
        : await core.preview(rawPackage);
    return OperationSyncSelection(
      fileName: file.name,
      fileSize: file.bytes.length,
      package: package,
      preview: preview,
      isRecovery: isRecovery,
    );
  }

  @override
  Future<void> apply(OperationSyncSelection selection) {
    return core.apply(
      package: selection.package,
      preview: selection.preview,
      isRecoveryExecution: selection.isRecovery,
    );
  }

  static String fileNameFor(DateTime localTimestamp) {
    String two(int value) => value.toString().padLeft(2, '0');
    return 'operation_reboot_transfer_'
        '${localTimestamp.year}-${two(localTimestamp.month)}-'
        '${two(localTimestamp.day)}_'
        '${two(localTimestamp.hour)}${two(localTimestamp.minute)}'
        '${two(localTimestamp.second)}.json';
  }
}
