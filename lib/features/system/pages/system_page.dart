import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/state/app_initialization_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../repositories/app_repository_container.dart';
import '../../operation_date/services/daily_finalize_undo_service.dart';
import '../../operation_date/services/japanese_holiday_reference_service.dart';
import '../services/app_data_initialization_service.dart';
import '../services/storage_status_gateway.dart';

class SystemDataHealthSnapshot {
  const SystemDataHealthSnapshot({
    required this.integrity,
    required this.recoveryStatus,
    required this.healthStatus,
  });

  final String integrity;
  final String recoveryStatus;
  final String healthStatus;
}

class SystemPage extends StatefulWidget {
  const SystemPage({
    super.key,
    this.initializationService,
    this.dataHealthLoader,
    this.storageGateway,
    this.holidayService,
  });

  final AppDataInitializationService? initializationService;
  final Future<SystemDataHealthSnapshot> Function()? dataHealthLoader;
  final StorageStatusGateway? storageGateway;
  final JapaneseHolidayReferenceService? holidayService;

  @override
  State<SystemPage> createState() => _SystemPageState();
}

class _SystemPageState extends State<SystemPage> {
  late Future<SystemDataHealthSnapshot> _dataHealth;
  late Future<StorageStatusSnapshot> _storageStatus;
  late Future<DailyFinalizeUndoInspection> _undoInspection;
  late Future<JapaneseHolidayDataStatus> _holidayData;
  bool _initializing = false;
  bool _holidayUpdating = false;
  String? _initializationResult;

  @override
  void initState() {
    super.initState();
    _dataHealth = _loadDataHealth();
    _storageStatus = (widget.storageGateway ?? StorageStatusGateway.platform())
        .load();
    _undoInspection = DailyFinalizeUndoService(
      AppRepositoryRegistry.container.database,
    ).inspect();
    _holidayData = _holidayService.load();
  }

  JapaneseHolidayReferenceService get _holidayService =>
      widget.holidayService ?? JapaneseHolidayReferenceService.instance;

  Future<void> _updateHolidayData() async {
    setState(() => _holidayUpdating = true);
    final status = await _holidayService.update();
    if (!mounted) return;
    setState(() {
      _holidayData = Future.value(status);
      _holidayUpdating = false;
    });
    final message = status.updateSucceeded
        ? '祝日データを更新しました。'
        : status.isAvailable
        ? '更新できませんでした。既存のキャッシュを維持します。'
        : '更新できませんでした。祝日判定は利用できません。';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<SystemDataHealthSnapshot> _loadDataHealth() async {
    final customLoader = widget.dataHealthLoader;
    if (customLoader != null) return customLoader();
    if (!AppRepositoryRegistry.hasContainer) {
      return const SystemDataHealthSnapshot(
        integrity: 'UNAVAILABLE',
        recoveryStatus: 'UNAVAILABLE',
        healthStatus: 'CHECK REQUIRED',
      );
    }
    try {
      final operationState = await AppRepositoryRegistry
          .container
          .operationState
          .findCurrent();
      final initialization = appInitializationController.value;
      final recoveryRequired =
          operationState?.requiresRecovery == true ||
          initialization.operationRecoveryRequired ||
          initialization.operationSyncRecoveryRequired;
      return SystemDataHealthSnapshot(
        integrity: operationState == null ? 'CHECK REQUIRED' : 'READABLE',
        recoveryStatus: recoveryRequired
            ? 'RECOVERY REQUIRED'
            : 'NO RECOVERY REQUIRED',
        healthStatus: operationState != null && !recoveryRequired
            ? 'HEALTHY'
            : 'ATTENTION',
      );
    } catch (_) {
      return const SystemDataHealthSnapshot(
        integrity: 'CHECK REQUIRED',
        recoveryStatus: 'UNKNOWN',
        healthStatus: 'ATTENTION',
      );
    }
  }

  Future<void> _requestInitialization() async {
    final confirmed = await _showInitializationDialog();
    if (confirmed != true || !mounted) return;
    setState(() {
      _initializing = true;
      _initializationResult = null;
    });
    try {
      final service =
          widget.initializationService ??
          AppDataInitializationService(
            AppRepositoryRegistry.container.database,
          );
      await service.initialize();
      appInitializationController.markReady();
      if (!mounted) return;
      setState(() {
        _initializationResult = 'アプリデータを初期化しました';
        _dataHealth = _loadDataHealth();
        _undoInspection = DailyFinalizeUndoService(
          AppRepositoryRegistry.container.database,
        ).inspect();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializationResult = 'アプリデータを初期化できませんでした';
      });
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<bool?> _showInitializationDialog() => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _InitializationConfirmationDialog(),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SYSTEM')),
    body: ListView(
      key: const ValueKey('system-content'),
      padding: AppSpacing.cardPadding,
      children: [
        _SystemSection(
          icon: Icons.devices_outlined,
          title: 'DEVICE TRANSFER',
          description:
              '機種変更などのデータ転送や、'
              '長期保存データの一括取り込みを行います。',
          buttonText: 'OPEN DEVICE TRANSFER',
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.deviceTransfer),
        ),
        AppSpacing.gapXL,
        FutureBuilder<DailyFinalizeUndoInspection>(
          future: _undoInspection,
          builder: (context, snapshot) {
            final inspection = snapshot.data;
            final canOpen = inspection?.canUndo == true;
            return _SystemSection(
              icon: Icons.event_available_outlined,
              title: 'LAST FINALIZE',
              description: canOpen
                  ? '直前に成功したFINALIZEを一度だけ取り消せます。'
                  : inspection?.targetDate.isNotEmpty == true
                  ? 'UNDO LAST FINALIZEは現在実行できません。'
                  : '取り消せる直前のFINALIZEはありません。',
              buttonText: 'OPEN LAST FINALIZE',
              onPressed: canOpen
                  ? () => Navigator.pushNamed(
                      context,
                      AppRoutes.logConfirmationDetail,
                    )
                  : null,
            );
          },
        ),
        AppSpacing.gapXL,
        _StorageSection(snapshot: _storageStatus),
        AppSpacing.gapXL,
        _HolidayDataSection(
          snapshot: _holidayData,
          busy: _holidayUpdating,
          onUpdate: _updateHolidayData,
        ),
        AppSpacing.gapXL,
        _DataHealthSection(snapshot: _dataHealth),
        AppSpacing.gapXL,
        _InitializeSection(
          busy: _initializing,
          result: _initializationResult,
          onPressed: appInitializationController.value.canWrite
              ? _requestInitialization
              : null,
        ),
        AppSpacing.gapXL,
        _SystemSection(
          icon: Icons.bug_report_outlined,
          title: 'STARTUP DIAGNOSTIC',
          description: 'iOS/PWA起動表示の一時的な診断トレースを確認します。',
          buttonText: 'OPEN STARTUP DIAGNOSTIC',
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.startupDiagnostic),
        ),
        AppSpacing.gapXL,
        _SystemSection(
          icon: Icons.animation_outlined,
          title: 'ANIMATIONS SANDBOX',
          description: 'アニメーション演出を本番導入前に確認します。',
          buttonText: 'OPEN ANIMATIONS SANDBOX',
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.animationsSandbox),
        ),
        AppSpacing.gapLG,
      ],
    ),
  );
}

class _InitializationConfirmationDialog extends StatefulWidget {
  const _InitializationConfirmationDialog();

  @override
  State<_InitializationConfirmationDialog> createState() =>
      _InitializationConfirmationDialogState();
}

class _InitializationConfirmationDialogState
    extends State<_InitializationConfirmationDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('INITIALIZE APP DATA'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Operation Rebootの運用データを初期化します。実行前に'
          'BACKUP & RESTOREからバックアップを作成してください。',
        ),
        AppSpacing.gapMD,
        const Text('続行するには INITIALIZE と入力してください。'),
        AppSpacing.gapSM,
        TextField(
          key: const ValueKey('initialize-confirmation-input'),
          controller: _controller,
          autofocus: true,
          minLines: 1,
          maxLines: 2,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(labelText: '確認文字列'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('キャンセル'),
      ),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, child) => FilledButton(
          key: const ValueKey('confirm-initialize-app-data'),
          onPressed: value.text == 'INITIALIZE' && value.composing.isCollapsed
              ? () => Navigator.pop(context, true)
              : null,
          child: child,
        ),
        child: const Text('初期化する'),
      ),
    ],
  );
}

class _StorageSection extends StatelessWidget {
  const _StorageSection({required this.snapshot});

  final Future<StorageStatusSnapshot> snapshot;

  @override
  Widget build(BuildContext context) => FutureBuilder<StorageStatusSnapshot>(
    future: snapshot,
    builder: (context, value) {
      final data = value.data;
      final estimate = data == null
          ? '取得中です'
          : switch (data.estimateState) {
              StorageEstimateState.available => null,
              StorageEstimateState.unsupported => 'このブラウザでは取得できません',
              StorageEstimateState.failed => '保存容量の取得に失敗しました',
            };
      final persistence = switch (data?.persistence) {
        StoragePersistence.persistent => (
          '永続保存',
          'ブラウザによる自動削除の対象外として保存されています。',
        ),
        StoragePersistence.bestEffort => (
          'ブラウザ管理',
          'ブラウザの判断によってデータが削除される可能性があります。',
        ),
        _ => ('確認できません', 'このブラウザでは保存状態を確認できません。'),
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(icon: Icons.storage_outlined, title: 'STORAGE'),
          AppSpacing.gapSM,
          OperationCard(
            child: Column(
              children: [
                const _StorageValue(label: '保存方式', value: 'IndexedDB'),
                const Divider(),
                _StorageValue(
                  label: '推定使用量',
                  value: estimate ?? _formatBytes(data!.usageBytes),
                ),
                const Divider(),
                _StorageValue(
                  label: '推定上限容量',
                  value: estimate ?? _formatBytes(data!.quotaBytes),
                ),
                const Divider(),
                _StorageValue(
                  label: '保存状態',
                  value: persistence.$1,
                  description: persistence.$2,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  static String _formatBytes(double? bytes) {
    if (bytes == null) return 'このブラウザでは取得できません';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes;
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} ${units[unit]}';
  }
}

class _StorageValue extends StatelessWidget {
  const _StorageValue({
    required this.label,
    required this.value,
    this.description,
  });

  final String label;
  final String value;
  final String? description;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(value), if (description != null) Text(description!)],
    ),
  );
}

class _HolidayDataSection extends StatelessWidget {
  const _HolidayDataSection({
    required this.snapshot,
    required this.busy,
    required this.onUpdate,
  });

  final Future<JapaneseHolidayDataStatus> snapshot;
  final bool busy;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(
        icon: Icons.event_available_outlined,
        title: 'HOLIDAY DATA',
      ),
      AppSpacing.gapSM,
      OperationCard(
        child: FutureBuilder<JapaneseHolidayDataStatus>(
          future: snapshot,
          builder: (context, value) {
            final status = value.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StorageValue(
                  label: 'SOURCE',
                  value: 'CABINET OFFICE JAPAN',
                ),
                const Divider(),
                _StorageValue(
                  label: 'DATA UPDATED',
                  value: _formatHolidayTimestamp(
                    status?.snapshot?.dataUpdatedAt,
                  ),
                ),
                const Divider(),
                _StorageValue(
                  label: 'LOCAL UPDATED',
                  value: _formatHolidayTimestamp(status?.localUpdatedAt),
                ),
                const Divider(),
                _StorageValue(
                  label: 'STATUS',
                  value: status?.isAvailable != true
                      ? 'NOT AVAILABLE'
                      : status!.usingBundled
                      ? 'AVAILABLE — BUNDLED'
                      : status.updateSucceeded
                      ? 'AVAILABLE — LOCAL'
                      : 'UPDATE FAILED — USING LOCAL',
                ),
                AppSpacing.gapMD,
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    key: const ValueKey('update-holiday-data'),
                    onPressed: busy ? null : onUpdate,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('UPDATE'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

String _formatHolidayTimestamp(DateTime? value) {
  if (value == null) return 'NOT AVAILABLE';
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

class _DataHealthSection extends StatelessWidget {
  const _DataHealthSection({required this.snapshot});

  final Future<SystemDataHealthSnapshot> snapshot;

  @override
  Widget build(BuildContext context) => FutureBuilder<SystemDataHealthSnapshot>(
    future: snapshot,
    builder: (context, value) {
      final data = value.data;
      return _ReadOnlySection(
        icon: Icons.health_and_safety_outlined,
        title: 'DATA HEALTH',
        values: [
          ('データ整合性', _localizedDataHealthStatus(data?.integrity ?? 'CHECKING')),
          (
            '復旧状態',
            _localizedDataHealthStatus(data?.recoveryStatus ?? 'CHECKING'),
          ),
          (
            'システム状態',
            _localizedDataHealthStatus(data?.healthStatus ?? 'CHECKING'),
          ),
        ],
      );
    },
  );
}

String _localizedDataHealthStatus(String value) => switch (value) {
  'READABLE' => '読み取り可能',
  'NO RECOVERY REQUIRED' => '復旧は必要ありません',
  'RECOVERY REQUIRED' => '復旧が必要です',
  'HEALTHY' => '正常',
  'CHECK REQUIRED' || 'ATTENTION' => '確認が必要です',
  'CHECKING' => '確認中です',
  'UNAVAILABLE' => '利用できません',
  'UNKNOWN' => '確認できません',
  _ => '確認できません',
};

class _InitializeSection extends StatelessWidget {
  const _InitializeSection({
    required this.busy,
    required this.result,
    required this.onPressed,
  });

  final bool busy;
  final String? result;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(
        icon: Icons.warning_amber_rounded,
        title: 'INITIALIZE APP DATA',
      ),
      AppSpacing.gapSM,
      OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'DANGER ZONE',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            AppSpacing.gapSM,
            const Text(
              'STATUS、ACTIVITY、TRAINING、FOODおよび運用履歴を初期化します。'
              'この操作は元に戻せません。',
            ),
            AppSpacing.gapMD,
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                key: const ValueKey('initialize-app-data'),
                onPressed: busy ? null : onPressed,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever_outlined),
                label: Text(busy ? '初期化しています' : 'アプリデータを初期化'),
              ),
            ),
            if (result != null) ...[AppSpacing.gapSM, Text(result!)],
          ],
        ),
      ),
    ],
  );
}

class _ReadOnlySection extends StatelessWidget {
  const _ReadOnlySection({
    required this.icon,
    required this.title,
    required this.values,
  });

  final IconData icon;
  final String title;
  final List<(String, String)> values;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(icon: icon, title: title),
      AppSpacing.gapSM,
      OperationCard(
        child: Column(
          children: [
            for (var index = 0; index < values.length; index++) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(values[index].$1),
                subtitle: Text(values[index].$2),
              ),
              if (index != values.length - 1) const Divider(),
            ],
          ],
        ),
      ),
    ],
  );
}

class _SystemSection extends StatelessWidget {
  const _SystemSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(icon: icon, title: title),
      AppSpacing.gapSM,
      OperationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(description),
            AppSpacing.gapMD,
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 20),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(buttonText),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
