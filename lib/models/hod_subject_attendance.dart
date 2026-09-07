/// Matches the backend `HodSubjectAttendanceDTO`.
///
/// [percentage] is nullable — `null` means no recorded attendance for the
/// subject. The backend is the single source of truth for every value.
class HodSubjectAttendance {
  final String subjectCode;
  final String subjectName;
  final int presentCount;
  final int totalRecordedCount;
  final double? percentage;

  const HodSubjectAttendance({
    required this.subjectCode,
    required this.subjectName,
    required this.presentCount,
    required this.totalRecordedCount,
    this.percentage,
  });

  factory HodSubjectAttendance.fromJson(Map<String, dynamic> json) {
    return HodSubjectAttendance(
      subjectCode: json['subjectCode'] as String? ?? '',
      subjectName: json['subjectName'] as String? ?? '',
      presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
      totalRecordedCount: (json['totalRecordedCount'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble(),
    );
  }
}