/// Matches the backend `HodSectionAttendanceDTO`.
///
/// [percentage] is nullable — `null` means no recorded attendance for the
/// section. The backend is the single source of truth for every value.
class HodSectionAttendance {
  final String sectionName;
  final String sectionCode;
  final int studentCount;
  final int presentCount;
  final int totalRecordedCount;
  final double? percentage;

  const HodSectionAttendance({
    required this.sectionName,
    required this.sectionCode,
    required this.studentCount,
    required this.presentCount,
    required this.totalRecordedCount,
    this.percentage,
  });

  factory HodSectionAttendance.fromJson(Map<String, dynamic> json) {
    return HodSectionAttendance(
      sectionName: json['sectionName'] as String? ?? '',
      sectionCode: json['sectionCode'] as String? ?? '',
      studentCount: (json['studentCount'] as num?)?.toInt() ?? 0,
      presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
      totalRecordedCount: (json['totalRecordedCount'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble(),
    );
  }
}