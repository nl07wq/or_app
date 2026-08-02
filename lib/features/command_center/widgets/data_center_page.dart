import 'package:flutter/material.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/operation_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../import_export/models/backup_package.dart';
import '../../operation_date/models/operation_state.dart';
import '../../repositories/app_repository_container.dart';

typedef DataCenterStateLoader = Future<OperationState> Function();

class DataCenterPage extends StatelessWidget {
  const DataCenterPage({super.key, this.stateLoader});

  final DataCenterStateLoader? stateLoader;

  Future<OperationState> _loadState() =>
      stateLoader?.call() ??
      AppRepositoryRegistry.container.operationState.requireCurrent();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OperationState>(
      future: _loadState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const _DataCenterError();
        }
        return _DataCenterContent(state: snapshot.requireData);
      },
    );
  }
}

class _DataCenterContent extends StatelessWidget {
  const _DataCenterContent({required this.state});

  final OperationState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('data-center-content'),
      padding: AppSpacing.cardPadding,
      children: [
        const SectionHeader(icon: Icons.storage_outlined, title: 'DATA CENTER'),
        AppSpacing.gapSM,
        const Text('Operation Rebootのデータを保存・復元・連携する施設です。'),
        AppSpacing.gapXL,
        const SectionHeader(
          icon: Icons.storage_outlined,
          title: 'SYSTEM STATE',
        ),
        AppSpacing.gapSM,
        _SystemStateCard(state: state),
        AppSpacing.gapXL,
        const SectionHeader(
          icon: Icons.settings_backup_restore,
          title: 'BACKUP & RESTORE',
        ),
        AppSpacing.gapSM,
        const OperationCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Operation Rebootの正式データをBackup Schema 3.0形式で保存・復元します。'),
              AppSpacing.gapSM,
              Text('BACKUP SCHEMA 3.0'),
              Text('OPERATION STATE INCLUDED'),
              Text('7 FORMAL SECTIONS'),
            ],
          ),
        ),
        AppSpacing.gapSM,
        _DataCenterActionButton(
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.backupRestore),
        ),
        AppSpacing.gapXL,
        const SectionHeader(
          icon: Icons.monitor_heart_outlined,
          title: 'SYSTEM MONITORING',
        ),
        AppSpacing.gapSM,
        const _ComingLaterCard(
          description: '復元履歴とデータ整合性の確認機能を今後追加します。',
          items: ['IMPORT HISTORY', 'CONFLICTS', 'QUARANTINE'],
        ),
        AppSpacing.gapLG,
      ],
    );
  }
}

class _SystemStateCard extends StatelessWidget {
  const _SystemStateCard({required this.state});

  final OperationState state;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        _StateValue(
          label: 'CURRENT OPERATION DATE',
          value: state.operationDate.value,
        ),
        const _StateValue(
          label: 'BACKUP SCHEMA',
          value: '${BackupPackage.currentSchemaVersion}.0',
        ),
        const _StateValue(label: 'ENVELOPE VERSION', value: '1'),
      ],
    ),
  );
}

class _StateValue extends StatelessWidget {
  const _StateValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label $value',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        AppSpacing.gapXS,
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

class _ComingLaterCard extends StatelessWidget {
  const _ComingLaterCard({required this.description, required this.items});

  final String description;
  final List<String> items;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(description),
        AppSpacing.gapMD,
        for (final item in items) ...[
          _ComingLaterItem(label: item),
          if (item != items.last) AppSpacing.gapSM,
        ],
      ],
    ),
  );
}

class _ComingLaterItem extends StatelessWidget {
  const _ComingLaterItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final labelRow = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(label)),
        ],
      );
      if (constraints.maxWidth < 300) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [labelRow, AppSpacing.gapXS, const Text('COMING LATER')],
        );
      }
      return Row(
        children: [
          Expanded(child: labelRow),
          const SizedBox(width: 8),
          const Text('COMING LATER'),
        ],
      );
    },
  );
}

class _DataCenterActionButton extends StatelessWidget {
  const _DataCenterActionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: onPressed,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings_backup_restore, size: 20),
          SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('OPEN BACKUP & RESTORE'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DataCenterError extends StatelessWidget {
  const _DataCenterError();

  @override
  Widget build(BuildContext context) => const Center(
    child: OperationCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline),
          AppSpacing.gapSM,
          Text('Operation Stateを読み込めませんでした。'),
        ],
      ),
    ),
  );
}
