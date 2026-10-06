import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/device_settings_controller.dart';
import '../../reminders/models/reminder_occurrence.dart';
import '../../reminders/services/reminder_occurrence_service.dart';
import '../../repositories/app_repository_container.dart';
import '../../schedule/services/schedule_recurrence_service.dart';
import 'notification_projection.dart';
import 'push_bridge.dart';

enum NotificationReconciliationState {
  idle,
  pending,
  syncing,
  synchronized,
  failed,
}

@immutable
class NotificationRuntimeStatus {
  const NotificationRuntimeStatus({
    this.permission = 'unknown',
    this.subscription = 'unknown',
    this.profile = 'missing',
    this.reconciliation = NotificationReconciliationState.idle,
    this.pendingSync = false,
    this.nextTrigger,
    this.pendingProjections = 0,
    this.lastPushResult,
    this.failedSubscriptions = 0,
    this.quotaState = 'unknown',
    this.error,
  });

  final String permission;
  final String subscription;
  final String profile;
  final NotificationReconciliationState reconciliation;
  final bool pendingSync;
  final DateTime? nextTrigger;
  final int pendingProjections;
  final String? lastPushResult;
  final int failedSubscriptions;
  final String quotaState;
  final String? error;

  NotificationRuntimeStatus copyWith({
    String? permission,
    String? subscription,
    String? profile,
    NotificationReconciliationState? reconciliation,
    bool? pendingSync,
    DateTime? nextTrigger,
    bool clearNextTrigger = false,
    int? pendingProjections,
    String? lastPushResult,
    int? failedSubscriptions,
    String? quotaState,
    String? error,
    bool clearError = false,
  }) => NotificationRuntimeStatus(
    permission: permission ?? this.permission,
    subscription: subscription ?? this.subscription,
    profile: profile ?? this.profile,
    reconciliation: reconciliation ?? this.reconciliation,
    pendingSync: pendingSync ?? this.pendingSync,
    nextTrigger: clearNextTrigger ? null : (nextTrigger ?? this.nextTrigger),
    pendingProjections: pendingProjections ?? this.pendingProjections,
    lastPushResult: lastPushResult ?? this.lastPushResult,
    failedSubscriptions: failedSubscriptions ?? this.failedSubscriptions,
    quotaState: quotaState ?? this.quotaState,
    error: clearError ? null : (error ?? this.error),
  );
}

class NotificationProfileController
    extends ValueNotifier<NotificationRuntimeStatus> {
  NotificationProfileController({
    PushBridge bridge = const PushBridge(),
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _bridge = bridge,
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       super(const NotificationRuntimeStatus());

  static const apiBase = String.fromEnvironment('OR_APP_NOTIFICATION_API');
  static const _profileIdKey = 'or_app_notification_profile_id_v1';
  static const _profileSecretKey = 'or_app_notification_profile_secret_v1';
  static const _installationIdKey = 'or_app_notification_installation_id_v1';
  static const _outboxKey = 'or_app_notification_outbox_v1';
  static final instance = NotificationProfileController();

  final PushBridge _bridge;
  final Future<SharedPreferences> Function() _preferencesLoader;
  String? _profileId;
  String? _profileSecret;
  String? _installationId;
  bool _initialized = false;
  bool _syncing = false;

  String? get profileId => _profileId;
  String get timeZone => _bridge.timeZone();
  bool get configured => _profileId != null && _profileSecret != null;

  Future<void> initialize() async {
    if (_initialized) return;
    final preferences = await _preferencesLoader();
    _profileId = preferences.getString(_profileIdKey);
    _profileSecret = preferences.getString(_profileSecretKey);
    _installationId = preferences.getString(_installationIdKey);
    _installationId ??= _bridge.randomToken();
    await preferences.setString(_installationIdKey, _installationId!);
    _initialized = true;
    value = value.copyWith(
      permission: _bridge.permission(),
      profile: configured ? 'configured' : 'missing',
      pendingSync: preferences.containsKey(_outboxKey),
    );
    if (configured && preferences.containsKey(_outboxKey))
      unawaited(syncPending());
  }

  Future<String> createProfile() async {
    _requireApi();
    await initialize();
    final profileId = _bridge.randomToken(24);
    final profileSecret = _bridge.randomToken(32);
    final recoverySecret = _bridge.randomToken(32);
    await _bridge.request(
      '$apiBase/v1/profiles/$profileId',
      'POST',
      body: jsonEncode({
        'profileId': profileId,
        'profileSecret': profileSecret,
        'recoverySecret': recoverySecret,
      }),
    );
    await _storeProfile(profileId, profileSecret);
    return recoverySecret;
  }

  Future<void> recoverProfile(String profileId, String recoverySecret) async {
    _requireApi();
    final raw = await _bridge.request(
      '$apiBase/v1/profiles/$profileId/recover',
      'POST',
      body: jsonEncode({'recoverySecret': recoverySecret.trim()}),
    );
    final result = jsonDecode(raw) as Map<String, dynamic>;
    await _storeProfile(profileId, result['profileSecret'] as String);
  }

  Future<String> createPairingPayload() async {
    await initialize();
    if (!configured)
      throw StateError('Notification Profile is not configured.');
    final code = _bridge.randomToken(32);
    await _bridge.request(
      '$apiBase/v1/profiles/$_profileId/pairing',
      'POST',
      token: _profileSecret,
      body: jsonEncode({'code': code}),
    );
    return jsonEncode({'v': 1, 'profileId': _profileId, 'code': code});
  }

  Future<void> consumePairingPayload(String payload) async {
    _requireApi();
    await initialize();
    final parsed = jsonDecode(payload) as Map<String, dynamic>;
    final profileId = parsed['profileId'] as String;
    final raw = await _bridge.request(
      '$apiBase/v1/profiles/$profileId/pairing/consume',
      'POST',
      body: jsonEncode({
        'code': parsed['code'],
        'installationId': _installationId,
      }),
    );
    final result = jsonDecode(raw) as Map<String, dynamic>;
    await _storeProfile(profileId, result['profileSecret'] as String);
  }

  Future<void> enablePush() async {
    _requireApi();
    await initialize();
    if (!configured)
      throw StateError('Notification Profile is not configured.');
    final keyRaw = await _bridge.request('$apiBase/v1/vapid-public-key', 'GET');
    final key =
        (jsonDecode(keyRaw) as Map<String, dynamic>)['publicKey'] as String;
    final subscription = jsonDecode(await _bridge.subscribe(key));
    await _bridge.request(
      '$apiBase/v1/profiles/$_profileId/installations/$_installationId/subscription',
      'PUT',
      token: _profileSecret,
      body: jsonEncode(subscription),
    );
    value = value.copyWith(
      permission: _bridge.permission(),
      subscription: 'active',
      clearError: true,
    );
    await reconcileFromRepositories();
  }

  Future<void> reconcileFromRepositories() async {
    await initialize();
    if (!AppRepositoryRegistry.hasContainer) return;
    final now = DateTime.now().toUtc();
    final start = DateTime.now();
    final end = start.add(const Duration(days: 120));
    final container = AppRepositoryRegistry.container;
    final schedules = await ScheduleRecurrenceService(
      container.schedules,
    ).inRange(DateTimeRange(start: start, end: end));
    final reminders = await ReminderOccurrenceService(
      container.reminders,
    ).inRange(DateTimeRange(start: start, end: end));
    final occurrences = <NotificationSourceOccurrence>[
      for (final schedule in schedules)
        if (!schedule.occurrenceExcluded &&
            !schedule.completed &&
            schedule.notificationOffsetsMinutes.isNotEmpty)
          NotificationSourceOccurrence(
            entityType: 'schedule',
            entityId: schedule.id,
            localDate: schedule.localDate,
            allDay: schedule.allDay,
            startTime: schedule.startTime,
            timeZone: schedule.notificationTimeZone,
            offsetsMinutes: schedule.notificationOffsetsMinutes,
            title: schedule.title,
          ),
      for (final reminder in reminders)
        if (reminder.status == ReminderOccurrenceStatus.pending &&
            reminder.definition.notificationOffsetsMinutes.isNotEmpty)
          NotificationSourceOccurrence(
            entityType: 'reminder',
            entityId: reminder.id,
            localDate: reminder.localDate,
            allDay: reminder.definition.allDay,
            startTime: reminder.definition.time,
            timeZone: reminder.definition.notificationTimeZone,
            offsetsMinutes: reminder.definition.notificationOffsetsMinutes,
            title: reminder.definition.title,
          ),
    ];
    final projections = NotificationProjectionPlanner(_bridge.wallTimeToEpoch)
        .project(
          occurrences,
          privacyMode:
              DeviceSettingsController.instance.value.notificationPrivacyMode,
          now: now,
        );
    final body = jsonEncode({
      'generation': '${now.microsecondsSinceEpoch}',
      'projections': projections.map((value) => value.toJson()).toList(),
    });
    final preferences = await _preferencesLoader();
    await preferences.setString(_outboxKey, body);
    value = value.copyWith(
      reconciliation: NotificationReconciliationState.pending,
      pendingSync: true,
      pendingProjections: projections.length,
      nextTrigger: projections.isEmpty ? null : projections.first.triggerAt,
      clearNextTrigger: projections.isEmpty,
    );
    if (configured) await syncPending();
  }

  Future<void> syncPending() async {
    if (_syncing || !configured || apiBase.isEmpty) return;
    final preferences = await _preferencesLoader();
    final body = preferences.getString(_outboxKey);
    if (body == null) return;
    _syncing = true;
    value = value.copyWith(
      reconciliation: NotificationReconciliationState.syncing,
    );
    try {
      await _bridge.request(
        '$apiBase/v1/profiles/$_profileId/projections/reconcile',
        'PUT',
        token: _profileSecret,
        body: body,
      );
      await preferences.remove(_outboxKey);
      value = value.copyWith(
        reconciliation: NotificationReconciliationState.synchronized,
        pendingSync: false,
        clearError: true,
      );
      await refreshStatus();
    } catch (error) {
      value = value.copyWith(
        reconciliation: NotificationReconciliationState.failed,
        pendingSync: true,
        error: error.toString(),
      );
    } finally {
      _syncing = false;
    }
  }

  Future<void> refreshStatus() async {
    await initialize();
    final serviceWorker = await _bridge.serviceWorkerState();
    value = value.copyWith(
      permission: _bridge.permission(),
      subscription: serviceWorker,
      profile: configured ? 'configured' : 'missing',
    );
    if (!configured || apiBase.isEmpty) return;
    try {
      final raw = await _bridge.request(
        '$apiBase/v1/profiles/$_profileId/status',
        'GET',
        token: _profileSecret,
      );
      final status = jsonDecode(raw) as Map<String, dynamic>;
      value = value.copyWith(
        pendingProjections: status['pendingProjections'] as int? ?? 0,
        nextTrigger: DateTime.tryParse(
          status['nextTriggerAt'] as String? ?? '',
        ),
        clearNextTrigger: status['nextTriggerAt'] == null,
        lastPushResult: status['lastPushResult'] as String?,
        failedSubscriptions: status['failedSubscriptions'] as int? ?? 0,
        quotaState: status['quotaState'] as String? ?? 'unknown',
        clearError: true,
      );
    } catch (error) {
      value = value.copyWith(error: error.toString());
    }
  }

  Future<void> _storeProfile(String profileId, String profileSecret) async {
    final preferences = await _preferencesLoader();
    await preferences.setString(_profileIdKey, profileId);
    await preferences.setString(_profileSecretKey, profileSecret);
    _profileId = profileId;
    _profileSecret = profileSecret;
    value = value.copyWith(profile: 'configured', clearError: true);
  }

  void _requireApi() {
    if (apiBase.isEmpty)
      throw StateError('Notification API is not configured.');
  }

  @visibleForTesting
  void resetForTesting() {
    _profileId = null;
    _profileSecret = null;
    _installationId = null;
    _initialized = false;
    _syncing = false;
    value = const NotificationRuntimeStatus();
  }
}
