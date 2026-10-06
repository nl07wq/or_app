import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/services/device_settings_controller.dart';
import '../../../core/widgets/global_touch_ripple.dart';
import '../../../core/widgets/operation_button.dart';
import '../../../core/widgets/operation_card.dart';
import '../models/notification_configuration.dart';
import '../services/notification_profile_controller.dart';

class NotificationSettingsCard extends StatelessWidget {
  const NotificationSettingsCard({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    NotificationProfileController? profileController,
  }) : _profileController = profileController;

  final DeviceSettings settings;
  final ValueChanged<DeviceSettings> onSettingsChanged;
  final NotificationProfileController? _profileController;

  NotificationProfileController get profile =>
      _profileController ?? NotificationProfileController.instance;

  @override
  Widget build(BuildContext context) => OperationCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RadioGroup<NotificationPrivacyMode>(
          groupValue: settings.notificationPrivacyMode,
          onChanged: (value) {
            if (value != null) {
              onSettingsChanged(
                settings.copyWith(notificationPrivacyMode: value),
              );
            }
          },
          child: const Column(
            children: [
              RadioListTile(
                key: ValueKey('notification-title-visible'),
                value: NotificationPrivacyMode.titleVisible,
                title: Text('タイトルを表示'),
                subtitle: Text('Schedule / Reminder の最小限のタイトルだけを送信します。'),
              ),
              RadioListTile(
                key: ValueKey('notification-content-hidden'),
                value: NotificationPrivacyMode.contentHidden,
                title: Text('内容を隠す'),
                subtitle: Text('Cloudflareにはタイトルを送信しません。'),
              ),
            ],
          ),
        ),
        const Divider(),
        ValueListenableBuilder<NotificationRuntimeStatus>(
          valueListenable: profile,
          builder: (context, status, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('PROFILE  ${status.profile.toUpperCase()}'),
              Text('PUSH  ${status.subscription.toUpperCase()}'),
              const SizedBox(height: 8),
              if (!profile.configured)
                OperationButton(
                  text: 'NOTIFICATION PROFILEを作成',
                  icon: Icons.person_add_alt_outlined,
                  onPressed: () => _createProfile(context),
                ),
              if (profile.configured) ...[
                OperationButton(
                  text: 'この端末で通知を有効化',
                  icon: Icons.notifications_active_outlined,
                  onPressed: () => _run(context, profile.enablePush),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showPairing(context),
                  icon: const Icon(Icons.qr_code_2_outlined),
                  label: const Text('端末をペアリング'),
                ).actionableFeedback(),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _enterPairing(context),
                icon: const Icon(Icons.qr_code_scanner_outlined),
                label: const Text('ペアリングコードを入力'),
              ).actionableFeedback(),
              OutlinedButton.icon(
                onPressed: () => _recover(context),
                icon: const Icon(Icons.key_outlined),
                label: const Text('Recovery Secretで復旧'),
              ).actionableFeedback(),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _createProfile(BuildContext context) async {
    try {
      final recovery = await profile.createProfile();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('RECOVERY SECRET'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('この画面を閉じる前に、安全な場所へ保存してください。再表示できません。'),
              const SizedBox(height: 12),
              SelectableText(recovery),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('保存しました'),
            ).actionableFeedback(),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) _message(context, error);
    }
  }

  Future<void> _showPairing(BuildContext context) async {
    try {
      final payload = await profile.createPairingPayload();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('SECURE QR PAIRING'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(data: payload, size: 220),
              const Text('5分以内に新しい端末で読み取ってください。'),
              ExpansionTile(
                title: const Text('手動入力'),
                children: [SelectableText(payload)],
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) _message(context, error);
    }
  }

  Future<void> _enterPairing(BuildContext context) async {
    final payload = await _textDialog(context, 'PAIRING PAYLOAD', 'QRの内容を貼り付け');
    if (payload == null) return;
    await _run(context, () => profile.consumePairingPayload(payload));
  }

  Future<void> _recover(BuildContext context) async {
    final profileId = await _textDialog(context, 'PROFILE ID', 'Profile ID');
    if (profileId == null || !context.mounted) return;
    final secret = await _textDialog(
      context,
      'RECOVERY SECRET',
      'Recovery Secret',
      obscure: true,
    );
    if (secret == null) return;
    await _run(context, () => profile.recoverProfile(profileId.trim(), secret));
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      if (context.mounted) _message(context, '完了しました。');
    } catch (error) {
      if (context.mounted) _message(context, error);
    }
  }

  Future<String?> _textDialog(
    BuildContext context,
    String title,
    String label, {
    bool obscure = false,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(labelText: label),
        ).inputFeedback(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ).actionableFeedback(),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('続行'),
          ).actionableFeedback(),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _message(BuildContext context, Object message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message.toString())));
}
