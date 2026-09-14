import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/app_repository_container.dart';
import '../../training_analysis/services/recovery_evidence_shadow_v2_service.dart';
import '../models/information_notice.dart';

final ValueNotifier<int> informationNoticeRevision = ValueNotifier(0);

abstract class InformationNoticeMetadataStore {
  Future<List<InformationNotice>> load();

  Future<void> save(List<InformationNotice> notices);
}

class SharedPreferencesInformationNoticeMetadataStore
    implements InformationNoticeMetadataStore {
  static const _key = 'information_notice_metadata_v1';

  @override
  Future<List<InformationNotice>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return [
        for (final value in decoded)
          if (value is Map<String, dynamic>) ?InformationNotice.fromJson(value),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> save(List<InformationNotice> notices) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(notices.map((value) => value.toJson()).toList()),
    );
  }
}

abstract class InformationNoticeProducer {
  Future<List<InformationNoticeCandidate>> activeCandidates(DateTime now);
}

class RecoveryV2ReviewReadyInformationProducer
    implements InformationNoticeProducer {
  const RecoveryV2ReviewReadyInformationProducer({this.now});

  final DateTime Function()? now;

  @override
  Future<List<InformationNoticeCandidate>> activeCandidates(
    DateTime currentTime,
  ) async {
    final records = await AppRepositoryRegistry.container.training
        .findAllRecords();
    if (records.isEmpty) return const [];
    const shadow = RecoveryEvidenceShadowV2Service();
    final results = shadow.buildRecurring(
      records: records,
      now: now?.call() ?? currentTime,
    );
    final progress = [
      for (final result in results) shadow.validationProgress(result),
    ];
    final candidate = recoveryV2ReviewReadyCandidate(
      shadow.validationOverall(progress),
    );
    if (candidate == null) return const [];
    return [candidate];
  }
}

InformationNoticeCandidate? recoveryV2ReviewReadyCandidate(
  RecoveryEvidenceShadowValidationOverall overall,
) {
  if (overall != RecoveryEvidenceShadowValidationOverall.reviewReady) {
    return null;
  }
  const version = RecoveryEvidenceShadowV2Service.parameterVersion;
  return const InformationNoticeCandidate(
    id: 'recovery-v2-review-ready:$version',
    priority: InformationNoticePriority.review,
    category: 'RECOVERY V2 SHADOW',
    title: 'RECOVERY V2 BETA — REVIEW READY',
    message: '検証に必要な前向き観測が規定数に到達しました。Recovery V2の正式採用レビューを開始できます。',
    parameterVersion: version,
    actionLabel: 'SYSTEM MONITORINGを確認',
  );
}

/// Non-Formal operational notice metadata. Candidate eligibility is always
/// reconstructed from its producer; only read and dismiss interaction state is
/// retained locally.
class InformationNoticeService {
  InformationNoticeService({
    InformationNoticeMetadataStore? store,
    List<InformationNoticeProducer>? producers,
    DateTime Function()? now,
  }) : _store = store ?? SharedPreferencesInformationNoticeMetadataStore(),
       _producers =
           producers ?? const [RecoveryV2ReviewReadyInformationProducer()],
       _now = now ?? DateTime.now;

  final InformationNoticeMetadataStore _store;
  final List<InformationNoticeProducer> _producers;
  final DateTime Function() _now;

  Future<List<InformationNotice>> activeNotices() async =>
      (await _synchronize()).where((value) => value.isActive).toList();

  Future<List<InformationNotice>> history() => _synchronize();

  Future<void> markRead(String id) => _update(
    id,
    (value, now) => value.state == InformationNoticeState.unread
        ? value.copyWith(state: InformationNoticeState.read, readAt: now)
        : value,
  );

  Future<void> dismiss(String id) => _update(
    id,
    (value, now) => value.copyWith(
      state: InformationNoticeState.dismissed,
      dismissedAt: now,
    ),
  );

  Future<InformationNotice> createDebugNotice({
    required String title,
    required String message,
    required InformationNoticePriority priority,
  }) async {
    final notices = await _store.load();
    final now = _now();
    final notice = InformationNotice(
      id: 'debug:${now.toUtc().microsecondsSinceEpoch}:${notices.length}',
      priority: priority,
      category: 'DEBUG / TEST',
      title: title.trim(),
      message: message.trim(),
      parameterVersion: 'debug-v1',
      createdAt: now,
      state: InformationNoticeState.unread,
      provenance: InformationNoticeProvenance.debug,
    );
    await _save([...notices, notice]);
    return notice;
  }

  Future<void> deleteDebugNotice(String id) async {
    final notices = await _store.load();
    final updated = [
      for (final value in notices)
        if (!(value.id == id && value.isDebug)) value,
    ];
    if (updated.length != notices.length) await _save(updated);
  }

  Future<void> clearDebugNotices() async {
    final notices = await _store.load();
    final updated = notices.where((value) => !value.isDebug).toList();
    if (updated.length != notices.length) await _save(updated);
  }

  Future<void> _update(
    String id,
    InformationNotice Function(InformationNotice value, DateTime now) update,
  ) async {
    final notices = await _store.load();
    final now = _now();
    final updated = [
      for (final value in notices)
        if (value.id == id) update(value, now) else value,
    ];
    await _save(updated);
  }

  Future<List<InformationNotice>> _synchronize() async {
    final existing = await _store.load();
    final byId = {for (final value in existing) value.id: value};
    final now = _now();
    final candidates = <InformationNoticeCandidate>[];
    for (final producer in _producers) {
      candidates.addAll(await producer.activeCandidates(now));
    }
    final additions = [
      for (final candidate in candidates)
        if (!byId.containsKey(candidate.id)) _noticeFor(candidate, now),
    ];
    if (additions.isNotEmpty) {
      final updated = [...existing, ...additions];
      await _save(updated);
      return _sorted(updated);
    }
    return _sorted(existing);
  }

  InformationNotice _noticeFor(
    InformationNoticeCandidate candidate,
    DateTime now,
  ) => InformationNotice(
    id: candidate.id,
    priority: candidate.priority,
    category: candidate.category,
    title: candidate.title,
    message: candidate.message,
    parameterVersion: candidate.parameterVersion,
    createdAt: now,
    state: InformationNoticeState.unread,
    actionLabel: candidate.actionLabel,
    provenance: candidate.provenance,
  );

  Future<void> _save(List<InformationNotice> notices) async {
    await _store.save(notices);
    informationNoticeRevision.value++;
  }

  List<InformationNotice> _sorted(List<InformationNotice> notices) {
    final sorted = [...notices];
    sorted.sort((a, b) {
      final priority = b.priority.index.compareTo(a.priority.index);
      return priority != 0 ? priority : b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }
}
