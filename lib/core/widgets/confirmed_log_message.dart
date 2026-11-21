import 'package:flutter/material.dart';

import '../services/daily_log_mutation_guard.dart';
import '../../features/themes/base_camp/widgets/base_camp_operation_panel.dart';

void showConfirmedLogMessage(BuildContext context, Object error) {
  if (error is! ConfirmedDailyLogException) return;

  showBaseCampOperationNotice(
    context,
    title: 'RECORD LOCKED',
    message: 'この日のログは確定済みです。\n変更する場合は訂正処理を開始してください。',
    result: BaseCampOperationNoticeResult.failure,
    duration: const Duration(seconds: 3),
  );
}
