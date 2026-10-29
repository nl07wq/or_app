/// The product-wide civil timezone for schedules and reminders.
///
/// These records retain wall-clock dates and times. Normalization therefore
/// changes only the IANA identifier; it never converts a stored clock value.
const notificationTimeZoneAsiaTokyo = 'Asia/Tokyo';

String normalizeNotificationTimeZone(String? value) =>
    notificationTimeZoneAsiaTokyo;

Map<String, Object?> normalizeNotificationTimeZoneRecord(
  Map<String, Object?> source,
) {
  final normalized = Map<String, Object?>.from(source);
  normalized['notificationTimeZone'] = notificationTimeZoneAsiaTokyo;
  return normalized;
}
