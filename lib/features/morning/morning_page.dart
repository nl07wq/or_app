import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

import '../../core/widgets/operation_description.dart';
import '../../core/widgets/section_header.dart';
import '../operation_date/services/operation_date_service.dart';
import '../repositories/app_repository_container.dart';

import 'widgets/morning_history_button.dart';
import 'widgets/morning_manual_card.dart';

class MorningPage extends StatefulWidget {
  const MorningPage({super.key});

  @override
  State<MorningPage> createState() => _MorningPageState();
}

class _MorningPageState extends State<MorningPage> {
  late Future<bool> _statusExists = _currentStatusExists();

  Future<bool> _currentStatusExists() async {
    final localDate = (await const OperationDateService().current()).value;
    return await AppRepositoryRegistry.container.status.findByLocalDate(
          localDate,
        ) !=
        null;
  }

  void _refreshStatusEntry() {
    setState(() {
      _statusExists = _currentStatusExists();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('STATUS')),
      body: SingleChildScrollView(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(icon: Icons.edit_note, title: 'STATUS ENTRY'),

            AppSpacing.gapSM,

            const OperationDescription(
              text:
                  '体重・睡眠・勤務情報など\n'
                  '本日の状態を記録します。',
            ),

            AppSpacing.gapMD,

            FutureBuilder<bool>(
              future: _statusExists,
              builder: (context, snapshot) {
                final statusExists = snapshot.data ?? false;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MorningManualCard(
                      enabled:
                          snapshot.connectionState == ConnectionState.done &&
                          !snapshot.hasError &&
                          !statusExists,
                    ),
                    if (statusExists) ...[
                      AppSpacing.gapSM,
                      const OperationDescription(
                        text:
                            '本日のSTATUSは登録済みです。\n'
                            '編集する場合はRECORDから行ってください。',
                      ),
                    ],
                  ],
                );
              },
            ),

            AppSpacing.gapXL,

            const SectionHeader(icon: Icons.history, title: 'RECORD'),

            AppSpacing.gapSM,

            const OperationDescription(
              text:
                  '保存済みの状態履歴を\n'
                  '確認できます。',
            ),

            AppSpacing.gapMD,

            MorningHistoryButton(onReturn: _refreshStatusEntry),
          ],
        ),
      ),
    );
  }
}
