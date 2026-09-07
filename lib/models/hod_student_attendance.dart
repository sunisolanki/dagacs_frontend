/// Matches the backend `HodStudentAttendanceDTO`.
///
/// [percentage] is nullable — `null` means no recorded attendance for the
/// student. The backend is the single source of truth for every value.
class HodStudentAttendance {
  final String rollNumber;
  final String studentName;
  final String sectionName;
  final int presentCount;
  final int totalRecordedCount;
  final double? percentage;

  const HodStudentAttendance({
    required this.rollNumber,
    required this.studentName,
    required this.sectionName,
    required this.presentCount,
    required this.totalRecordedCount,
    this.percentage,
  });

  factory HodStudentAttendance.fromJson(Map<String, dynamic> json) {
    return HodStudentAttendance(
      rollNumber: json['rollNumber'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      sectionName: json['sectionName'] as String? ?? '',
      presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
      totalRecordedCount: (json['totalRecordedCount'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble(),
    );
  }
}