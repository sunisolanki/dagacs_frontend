/// One row of the HOD recording-coverage report (M7.1 `HodCoverageReportDTO`).
///
/// Coverage is RECORD-BACKED: only subject-sections with actual
/// AttendanceRecord rows appear; a session without records never contributes.
class HodCoverageRow {
  final String subjectCode;
  final String subjectName;
  final String sectionCode;
  final String sectionName;
  final int recordedDateCount;
  final int sessionCount;

  const HodCoverageRow({
    required this.subjectCode,
    required this.subjectName,
    required this.sectionCode,
    required this.sectionName,
    required this.recordedDateCount,
    required this.sessionCount,
  });

  factory HodCoverageRow.fromJson(Map<String, dynamic> json) {
    return HodCoverageRow(
      subjectCode: json['subjectCode'] as String? ?? '',
      subjectName: json['subjectName'] as String? ?? '',
      sectionCode: json['sectionCode'] as String? ?? '',
      sectionName: json['sectionName'] as String? ?? '',
      recordedDateCount: (json['recordedDateCount'] as num?)?.toInt() ?? 0,
      sessionCount: (json['sessionCount'] as num?)?.toInt() ?? 0,
    );
  }
}