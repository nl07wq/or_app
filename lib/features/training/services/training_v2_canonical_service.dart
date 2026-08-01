import '../../../core/models/training_session_v2.dart';
import '../../sync/services/orlo_sync_canonical_codec.dart';

abstract final class TrainingV2CanonicalService {
  static Map<String, Object?> value({
    required String localDate,
    required TrainingSessionV2 session,
  }) => {'localDate': localDate, 'session': session.toJson()};

  static String digest({
    required String localDate,
    required TrainingSessionV2 session,
  }) => OrloSyncCanonicalCodec.digest(
    value(localDate: localDate, session: session),
  );
}
