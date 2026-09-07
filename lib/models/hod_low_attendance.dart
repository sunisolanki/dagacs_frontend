/// Matches the backend `HodLowAttendanceDTO`.
///
/// The backend applies the FIXED 75.0% threshold (`percentage < 75.0`).
/// Flutter only displays the already-filtered list — it never re-applies or
/// configures a threshold.
class HodLowAttendance {
  final String rollNumber;
  final String studentName;
  final String sectionName;
  final int presentCount;
  final int totalRecordedCount;
  final double? percentage;

  const HodLowAttendance({
    required this.rollNumber,
    required this.studentName,
    required this.sectionName,
    required this.presentCount,
    required this.totalRecordedCount,
    this.percentage,
  });

  factory HodLowAttendance.fromJson(Map<String, dynamic> json) {
    return HodLowAttendance(
      rollNumber: json['rollNumber'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      sectionName: json['sectionName'] as String? ?? '',
      presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
      totalRecordedCount: (json['totalRecordedCount'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble(),
    );
  }
}