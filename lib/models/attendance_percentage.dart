/// Matches the backend M4.1 `AttendancePercentageDTO`.
///
/// The backend calculates the percentage. Flutter only consumes and displays
/// the result — it never recomputes the formula.
///
/// [percentage] is intentionally nullable. `null` means "no recorded attendance
/// exists" and must NOT be converted to 0. A non-null value is a single
/// authoritative percentage produced by the backend.
class AttendancePercentage {
  final int presentCount;
  final int totalRecordedCount;
  final double? percentage;

  const AttendancePercentage({
    required this.presentCount,
    required this.totalRecordedCount,
    this.percentage,
  });

  factory AttendancePercentage.fromJson(Map<String, dynamic> json) {
    return AttendancePercentage(
      presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
      totalRecordedCount: (json['totalRecordedCount'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble(),
    );
  }
}
