import 'package:flutter/material.dart';

import '../global_touch_ripple.dart';
import '../../../features/themes/base_camp/base_camp_presentation.dart';
import '../../../features/themes/base_camp/widgets/base_camp_operation_panel.dart';

Future<bool> showHistoryDeleteDialog(
  BuildContext context, {
  required String title,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      if (BaseCampPresentation.isActive(context)) {
        return BaseCampOperationPanel(
          title: 'DELETE RECORD',
          state: BaseCampOperationPanelState.confirmation,
          message: 'この$titleを削除しますか？\nこの操作は取り消せません。',
          actions: <Widget>[
            BaseCampOperationPanelButton(
              label: 'CANCEL',
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            BaseCampOperationPanelButton(
              label: 'DELETE',
              primary: true,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        );
      }
      return AlertDialog(
        title: Text('この$titleを削除しますか？'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          ActionableFeedbackButton(
            enabled: true,
            child: TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('キャンセル'),
            ),
          ),
          ActionableFeedbackButton(
            enabled: true,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('削除'),
            ),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
