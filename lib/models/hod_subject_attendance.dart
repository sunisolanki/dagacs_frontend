/// Matches the backend `HodSubjectAttendanceDTO`.
///
/// [percentage] is nullable — `null` means no recorded attendance for the
/// subject. The backend is the single source of truth for every value.
class HodSubjectAttendance {
  final String subjectCode;
  final String subjectName;

  /// Academic context; null on the department-wide query.
  final String? programName;
  final String? semesterName;
  final String? sectionName;

  /// Phase 3: stable identifier, populated only by the academic-context-scoped
  /// query. Null on the department-wide query, where the UI therefore does not
  /// offer a drill-down rather than guessing an id.
  final int? subjectId;

  final int presentCount;
  final int totalRecordedCount;
  final double? percentage;

  const HodSubjectAttendance({
    required this.subjectCode,
    required this.subjectName,
    required this.presentCount,
    required this.totalRecordedCount,
    this.programName,
    this.semesterName,
    this.sectionName,
    this.subjectId,
    this.percentage,
  });

  factory HodSubjectAttendance.fromJson(Map<String, dynamic> json) {
    return HodSubjectAttendance(
      subjectCode: json['subjectCode'] as String? ?? '',
      subjectName: json['subjectName'] as String? ?? '',
      programName: json['programName'] as String?,
      semesterName: json['semesterName'] as String?,
      sectionName: json['sectionName'] as String?,
      subjectId: (json['subjectId'] as num?)?.toInt(),
      presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
      totalRecordedCount: (json['totalRecordedCount'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble(),
    );
  }

  bool get hasAcademicContext => programName != null && semesterName != null;
}