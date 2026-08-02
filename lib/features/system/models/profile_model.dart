import '../data/profile_nationalities.dart';

abstract final class ProfileGender {
  static const male = 'male';
  static const female = 'female';
  static const preferNotToSay = 'prefer_not_to_say';
  static const values = {male, female, preferNotToSay};
}

class ProfileModel {
  static const recordId = 'current';
  static const recordVersion = 1;

  final String? userName;
  final double? heightCm;
  final String? gender;
  final String? nationality;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProfileModel({
    this.userName,
    this.heightCm,
    this.gender,
    this.nationality,
    this.createdAt,
    this.updatedAt,
  });

  factory ProfileModel.validated({
    String? userName,
    double? heightCm,
    String? gender,
    String? nationality,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final normalizedName = userName?.trim();
    final value = ProfileModel(
      userName: normalizedName == null || normalizedName.isEmpty
          ? null
          : normalizedName,
      heightCm: heightCm,
      gender: gender,
      nationality: nationality,
      createdAt: createdAt?.toUtc(),
      updatedAt: updatedAt?.toUtc(),
    );
    value.validate();
    return value;
  }

  factory ProfileModel.fromRecord(Map<String, Object?> record) {
    const allowed = {
      'id',
      'version',
      'userName',
      'heightCm',
      'gender',
      'nationality',
      'createdAt',
      'updatedAt',
    };
    if (record.keys.any((key) => !allowed.contains(key)) ||
        record['id'] != recordId ||
        record['version'] != recordVersion) {
      throw const FormatException('Invalid Profile record.');
    }
    final createdAt = record['createdAt'];
    final updatedAt = record['updatedAt'];
    if (createdAt is! String || updatedAt is! String) {
      throw const FormatException('Invalid Profile timestamp.');
    }
    final userName = _storedUserName(record);
    final parsedCreatedAt = DateTime.parse(createdAt).toUtc();
    final parsedUpdatedAt = DateTime.parse(updatedAt).toUtc();
    if (parsedUpdatedAt.isBefore(parsedCreatedAt)) {
      throw const FormatException('Invalid Profile timestamp order.');
    }
    return ProfileModel.validated(
      userName: userName,
      heightCm: _nullableDouble(record, 'heightCm'),
      gender: _nullableString(record, 'gender'),
      nationality: _nullableString(record, 'nationality'),
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  factory ProfileModel.fromBackupRecord(Map<String, Object?> record) {
    const allowed = {
      'version',
      'userName',
      'heightCm',
      'gender',
      'nationality',
    };
    if (record.keys.any((key) => !allowed.contains(key)) ||
        record['version'] != recordVersion) {
      throw const FormatException('Invalid Profile backup record.');
    }
    return ProfileModel.validated(
      userName: _storedUserName(record),
      heightCm: _nullableDouble(record, 'heightCm'),
      gender: _nullableString(record, 'gender'),
      nationality: _nullableString(record, 'nationality'),
    );
  }

  void validate() {
    final height = heightCm;
    if (height != null &&
        (!height.isFinite ||
            height <= 0 ||
            ((height * 10) - (height * 10).round()).abs() > 0.000000001)) {
      throw const FormatException('Invalid Profile height.');
    }
    if (gender != null && !ProfileGender.values.contains(gender)) {
      throw const FormatException('Invalid Profile gender.');
    }
    if (nationality != null &&
        !ProfileNationalities.values.contains(nationality)) {
      throw const FormatException('Invalid Profile nationality.');
    }
  }

  Map<String, Object?> toRecord({required DateTime now, DateTime? created}) {
    validate();
    final timestamp = now.toUtc();
    return {
      'id': recordId,
      'version': recordVersion,
      'userName': userName,
      'heightCm': heightCm,
      'gender': gender,
      'nationality': nationality,
      'createdAt': (created ?? createdAt ?? timestamp)
          .toUtc()
          .toIso8601String(),
      'updatedAt': timestamp.toIso8601String(),
    };
  }

  Map<String, Object?> toBackupRecord() {
    validate();
    return {
      'version': recordVersion,
      'userName': userName,
      'heightCm': heightCm,
      'gender': gender,
      'nationality': nationality,
    };
  }

  static String? _nullableString(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value != null && value is! String) {
      throw FormatException('Profile $key must be a String or null.');
    }
    return value as String?;
  }

  static String? _storedUserName(Map<String, Object?> record) {
    final value = _nullableString(record, 'userName');
    if (value != null && (value.isEmpty || value.trim() != value)) {
      throw const FormatException('Invalid Profile userName.');
    }
    return value;
  }

  static double? _nullableDouble(Map<String, Object?> record, String key) {
    final value = record[key];
    if (value == null) return null;
    if (value is! num) {
      throw FormatException('Profile $key must be a Number or null.');
    }
    return value.toDouble();
  }
}
