import 'package:flutter/material.dart';

import 'package:or_app/core/widgets/global_touch_ripple.dart';

import '../../core/models/activity_data.dart';
import '../../core/models/digestive_event.dart';
import '../../core/widgets/history/history_delete_dialog.dart';
import '../../core/widgets/ambient_page_scaffold.dart';
import '../../core/widgets/dashboard_glass_card.dart';
import '../../core/services/daily_log_mutation_guard.dart';
import '../../core/widgets/confirmed_log_message.dart';
import '../../core/state/app_initialization_state.dart';
import 'activity_entry_page.dart';
import 'models/activity_summary_state.dart';
import 'repository/activity_repository.dart';
import 'services/activity_digestive_record_presentation.dart';
import 'widgets/activity_mechanical_counter_title.dart';
import 'widgets/activity_mechanical_back_button.dart';
import 'widgets/activity_ambient_kinetic_field.dart';

class ActivityHistoryPage extends StatefulWidget {
  const ActivityHistoryPage({super.key});
  @override
  State<ActivityHistoryPage> createState() => _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends State<ActivityHistoryPage> {
  final _repository = const LocalActivityRepository();
  late Future<List<ActivityData>> _records;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _records = _repository.getAll();

  Future<void> _delete(ActivityData data) async {
    final confirmed = await showHistoryDeleteDialog(context, title: '活動記録');
    if (!confirmed) return;
    try {
      await deleteActivity(data.date);
    } on ConfirmedDailyLogException catch (error) {
      if (mounted) showConfirmedLogMessage(context, error);
      return;
    }
    _reload();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.paddingOf(context);
    return AmbientPageScaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
        leading: Navigator.canPop(context)
            ? const ActivityMechanicalBackButton()
            : null,
        title: const ActivityMechanicalCounterTitle(title: 'ACTIVITY RECORD'),
      ),
      ambient: const ActivityAmbientBackground(),
      body: FutureBuilder<List<ActivityData>>(
        future: _records,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data!;
          if (records.isEmpty) {
            return const Center(child: Text('No Activity Records'));
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              16,
              viewPadding.top + kToolbarHeight + 16,
              16,
              viewPadding.bottom + 16,
            ),
            itemCount: records.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = records[index];
              final previousCarryOver = _findPreviousCarryOver(
                records,
                data.date,
              );
              final officialSteps = data.officialStepsFor(previousCarryOver);

              return DashboardGlassCard(
                child: _ActivityRecordPlate(
                  data: data,
                  officialSteps: officialSteps,
                  previousCarryOver: previousCarryOver,
                  formatSteps: _formatSteps,
                  onEdit: appInitializationController.value.isReadOnly
                      ? null
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ActivityEntryPage(initialData: data),
                            ),
                          );
                          _reload();
                          setState(() {});
                        },
                  onDelete: appInitializationController.value.isReadOnly
                      ? null
                      : () => _delete(data),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatSteps(int steps) => steps.toString().replaceAllMapped(
    RegExp(r'(?<!^)(?=(\d{3})+$)'),
    (_) => ',',
  );

  int _findPreviousCarryOver(List<ActivityData> records, DateTime date) {
    final previousDate = DateTime(date.year, date.month, date.day - 1);
    for (final record in records) {
      if (record.date.year == previousDate.year &&
          record.date.month == previousDate.month &&
          record.date.day == previousDate.day) {
        return record.carryOver;
      }
    }
    return 0;
  }
}

class _ActivityRecordPlate extends StatelessWidget {
  const _ActivityRecordPlate({
    required this.data,
    required this.officialSteps,
    required this.previousCarryOver,
    required this.formatSteps,
    required this.onEdit,
    required this.onDelete,
  });
  final ActivityData data;
  final int officialSteps, previousCarryOver;
  final String Function(int) formatSteps;
  final VoidCallback? onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final date =
        '${data.date.year}-${data.date.month.toString().padLeft(2, '0')}-${data.date.day.toString().padLeft(2, '0')}';
    final digestive = data.digestiveEvents;
    final event = digestive != null && digestive.length == 1
        ? digestive.single
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(date, style: Theme.of(context).textTheme.titleMedium),
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
        Text(
          'OFFICIAL STEPS',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(letterSpacing: 1),
        ),
        Text(
          '${formatSteps(officialSteps)} steps',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        _ActivityDetail(
          'MEASURED STEPS',
          data.stepsEntered
              ? '${formatSteps(data.measuredSteps)} steps'
              : '未計測',
        ),
        _ActivityDetail(
          'CARRY OVER / ADJUSTMENT',
          '＋${formatSteps(data.carryOver)} / −${formatSteps(previousCarryOver)} steps',
        ),
        const SizedBox(height: 10),
        Text(
          'DIGESTIVE',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(letterSpacing: 1),
        ),
        const SizedBox(height: 5),
        if (event != null)
          Row(
            key: const Key('activity-record-digestive-horizontal'),
            children: [
              Expanded(
                child: _DigestiveValue(
                  'AMOUNT',
                  DigestiveEvent.amountLabel(event.amount),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DigestiveValue(
                  'SHAPE',
                  event.shape == null
                      ? '未計測'
                      : DigestiveEvent.shapeLabel(event.shape!),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DigestiveValue(
                  'RELIEF',
                  event.relief == null
                      ? '未計測'
                      : DigestiveEvent.reliefLabel(event.relief!),
                ),
              ),
            ],
          )
        else
          Text(
            ActivityDigestiveRecordPresentation.format(data),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        if (data.note?.isNotEmpty ?? false) ...[
          const SizedBox(height: 10),
          Text(
            'MEMO',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(letterSpacing: 1),
          ),
          Text(data.note!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _ActivityDetail extends StatelessWidget {
  const _ActivityDetail(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}

class _DigestiveValue extends StatelessWidget {
  const _DigestiveValue(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .26),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: .5),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}
