class ShiftPreset {
  const ShiftPreset({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.breakTime,
    required this.order,
  });

  final String id;
  final String name;
  final String startTime;
  final String endTime;
  final String breakTime;
  final int order;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'startTime': startTime,
    'endTime': endTime,
    'breakTime': breakTime,
    'order': order,
  };

  factory ShiftPreset.fromJson(Map<String, dynamic> json) {
    return ShiftPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      breakTime: json['breakTime'] as String,
      order: json['order'] as int,
    );
  }

  ShiftPreset copyWith({
    String? name,
    String? startTime,
    String? endTime,
    int? order,
  }) {
    return ShiftPreset(
      id: id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      breakTime: breakTime,
      order: order ?? this.order,
    );
  }
}
