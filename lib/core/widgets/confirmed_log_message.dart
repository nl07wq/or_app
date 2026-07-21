import 'package:flutter/material.dart';

import '../services/daily_log_mutation_guard.dart';

void showConfirmedLogMessage(BuildContext context, Object error) {
  if (error is! ConfirmedDailyLogException) return;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('この日のログは確定済みです。\n変更する場合は訂正処理を開始してください。'),
      ),
    );
}
