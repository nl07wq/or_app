import 'package:flutter/material.dart';

import 'package:or_app/core/widgets/global_touch_ripple.dart';

import '../../core/models/morning_data.dart';
import '../../core/repositories/morning_repository.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/history/history_delete_dialog.dart';
import '../../core/state/app_initialization_state.dart';
import '../../core/widgets/ambient_page_scaffold.dart';
import '../../core/widgets/dashboard_glass_card.dart';

import 'models/morning_fact_state.dart';
import 'morning_fact_page.dart';
import 'widgets/status_crt_back_button.dart';
import 'widgets/status_crt_monitor_title.dart';
import 'widgets/status_radial_spectrum_ambient.dart';

class MorningHistoryPage extends StatefulWidget {
  const MorningHistoryPage({super.key});

  @override
  State<MorningHistoryPage> createState() => _MorningHistoryPageState();
}

class _MorningHistoryPageState extends State<MorningHistoryPage> {
  late Future<List<MorningData>> _records;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  void _loadRecords() {
    _records = MorningRepository.getAll();
  }

  String formatTime(double hours) {
    final totalMinutes = (hours * 60).round();
    final hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;

    return '$hour時間$minute分';
  }

  Future<void> _deleteRecord(MorningData data) async {
    final result = await showHistoryDeleteDialog(context, title: '状態記録');

    if (!result) return;

    try {
      await DailyLogMutationGuard.assertDateMutable(DateTime.parse(data.date));
      await MorningRepository.remove(data);
    } on ConfirmedDailyLogException catch (error) {
      if (mounted) showConfirmedLogMessage(context, error);
      return;
    }
    await refreshMorningFact();

    _loadRecords();
    setState(() {});
  }

  Future<void> _editRecord(MorningData data) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MorningFactPage(data: data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return AmbientPageScaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
        leading: Navigator.canPop(context) ? const StatusCrtBackButton() : null,
        title: const StatusCrtMonitorTitle(),
      ),
      ambient: const StatusAmbientBackground(),
      body: FutureBuilder<List<MorningData>>(
        future: _records,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data!;

          if (records.isEmpty) {
            return const Center(child: Text('No Morning Records'));
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.cardPadding.left,
              topInset + AppSpacing.cardPadding.top,
              AppSpacing.cardPadding.right,
              AppSpacing.cardPadding.bottom,
            ),
            itemCount: records.length,
            separatorBuilder: (_, _) => AppSpacing.gapMD,
            itemBuilder: (context, index) {
              final data = records[index];

              return DashboardGlassCard(
                child: _StatusRecordPlate(
                  data: data,
                  formatTime: formatTime,
                  onEdit: appInitializationController.value.isReadOnly
                      ? null
                      : () => _editRecord(data),
                  onDelete: appInitializationController.value.isReadOnly
                      ? null
                      : () => _deleteRecord(data),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusRecordPlate extends StatelessWidget {
  const _StatusRecordPlate({
    required this.data,
    required this.formatTime,
    required this.onEdit,
    required this.onDelete,
  });

  final MorningData data;
  final String Function(double) formatTime;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                data.date.split('T').first,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: onEdit,
            ).actionableFeedback(),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: 'Delete',
              onPressed: onDelete,
            ).actionableFeedback(),
          ],
        ),
        const SizedBox(height: 10),
        _PlateSection(
          label: 'BODY',
          children: [
            _PlatePair(
              left: _PlateValue(
                'WEIGHT',
                data.weight == null
                    ? '未計測'
                    : '${data.weight!.toStringAsFixed(1)} kg',
              ),
              right: _PlateValue(
                'BODY FAT',
                data.bodyFat == null
                    ? '未計測'
                    : '${data.bodyFat!.toStringAsFixed(1)} %',
              ),
            ),
          ],
        ),
        _PlateSection(
          label: 'SLEEP',
          children: [
            _PlatePair(
              left: _PlateValue(
                'SLEEP TIME',
                data.sleepHours == null ? '未計測' : formatTime(data.sleepHours!),
              ),
              right: _PlateValue(
                'SLEEP SCORE',
                data.sleepScore?.toString() ?? '未計測',
              ),
            ),
            _PlateSecondary('SLEEP TYPE', data.sleepType.displayLabel),
          ],
        ),
        _PlateSection(
          label: 'FOOT',
          children: [
            _PlateValue(
              'FOOT PAIN',
              data.footPain == 0 ? '未計測' : 'LV. ${data.footPain} /10',
            ),
            if (data.condition != null)
              _PlateSecondary('CONDITION', '${data.condition}'),
            if (data.bowelAmount != null || data.bowelShape != null)
              _PlateSecondary(
                'LEGACY BOWEL',
                '量 ${data.bowelAmount ?? '-'} / 形 ${data.bowelShape ?? '-'}',
              ),
          ],
        ),
        _PlateSection(
          label: 'WORK',
          children: [
            if (data.workType.isWorking)
              _PlatePair(
                left: _PlateValue('SHIFT', data.workType.label),
                right: _PlateValue(
                  'BREAK',
                  data.workBreak.isNotEmpty ? data.workBreak : '未計測',
                ),
              )
            else
              _PlateValue('SHIFT', data.workType.label),
            if (data.workType.isWorking) ...[
              _PlateValue('WORK HOURS', formatTime(data.workHours)),
              _PlateSecondary(
                'START / END',
                '${data.workStart.isEmpty ? '未計測' : data.workStart} / ${data.workEnd.isEmpty ? '未計測' : data.workEnd}',
              ),
            ],
          ],
        ),
        _PlateSection(
          label: 'MEMO',
          children: [
            Text(
              data.memo.isEmpty ? 'なし' : data.memo,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }
}

class _PlateSection extends StatelessWidget {
  const _PlateSection({required this.label, required this.children});
  final String label;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.1,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        ...children,
      ],
    ),
  );
}

class _PlatePair extends StatelessWidget {
  const _PlatePair({required this.left, required this.right});
  final Widget left;
  final Widget right;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: left),
      const SizedBox(width: 8),
      Expanded(child: right),
    ],
  );
}

class _PlateValue extends StatelessWidget {
  const _PlateValue(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    key: Key('status-record-field-${label.toLowerCase().replaceAll(' ', '-')}'),
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .28),
      border: Border.all(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: .55),
      ),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(letterSpacing: .55),
        ),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    ),
  );
}

class _PlateSecondary extends StatelessWidget {
  const _PlateSecondary(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Text('$label  $value', style: Theme.of(context).textTheme.bodySmall),
  );
}
