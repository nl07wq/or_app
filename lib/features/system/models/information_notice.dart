enum InformationNoticeState { unread, read, dismissed }

enum InformationNoticePriority { informational, review, actionRequired, safety }

class InformationNoticeCandidate {
  const InformationNoticeCandidate({
    required this.id,
    required this.priority,
    required this.category,
    required this.title,
    required this.message,
    required this.parameterVersion,
    this.actionLabel,
  });

  final String id;
  final InformationNoticePriority priority;
  final String category;
  final String title;
  final String message;
  final String parameterVersion;
  final String? actionLabel;
}

class InformationNotice {
  const InformationNotice({
    required this.id,
    required this.priority,
    required this.category,
    required this.title,
    required this.message,
    required this.parameterVersion,
    required this.createdAt,
    required this.state,
    this.readAt,
    this.dismissedAt,
    this.actionLabel,
  });

  final String id;
  final InformationNoticePriority priority;
  final String category;
  final String title;
  final String message;
  final String parameterVersion;
  final DateTime createdAt;
  final InformationNoticeState state;
  final DateTime? readAt;
  final DateTime? dismissedAt;
  final String? actionLabel;

  bool get isActive => state != InformationNoticeState.dismissed;

  InformationNotice copyWith({
    InformationNoticeState? state,
    DateTime? readAt,
    DateTime? dismissedAt,
  }) => InformationNotice(
    id: id,
    priority: priority,
    category: category,
    title: title,
    message: message,
    parameterVersion: parameterVersion,
    createdAt: createdAt,
    state: state ?? this.state,
    readAt: readAt ?? this.readAt,
    dismissedAt: dismissedAt ?? this.dismissedAt,
    actionLabel: actionLabel,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'priority': priority.name,
    'category': category,
    'title': title,
    'message': message,
    'parameterVersion': parameterVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'state': state.name,
    'readAt': readAt?.toUtc().toIso8601String(),
    'dismissedAt': dismissedAt?.toUtc().toIso8601String(),
    'actionLabel': actionLabel,
  };

  static InformationNotice? fromJson(Map<String, dynamic> json) {
    try {
      final createdAt = DateTime.parse(json['createdAt'] as String).toLocal();
      return InformationNotice(
        id: json['id'] as String,
        priority: InformationNoticePriority.values.byName(
          json['priority'] as String,
        ),
        category: json['category'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        parameterVersion: json['parameterVersion'] as String,
        createdAt: createdAt,
        state: InformationNoticeState.values.byName(json['state'] as String),
        readAt: _date(json['readAt']),
        dismissedAt: _date(json['dismissedAt']),
        actionLabel: json['actionLabel'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
