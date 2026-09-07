/// Matches the backend `HodDashboardDTO`.
///
/// [overallPercentage] is intentionally nullable: `null` means no recorded
/// attendance exists and must NOT be displayed as 0%. All values are
/// authoritative backend aggregates — Flutter never recalculates them.
class HodDashboard {
  final String departmentName;
  final String departmentCode;
  final int programCount;
  final int batchCount;
  final int sectionCount;
  final int studentCount;
  final int totalRecordedCount;
  final int presentCount;
  final double? overallPercentage;

  const HodDashboard({
    required this.departmentName,
    required this.departmentCode,
    required this.programCount,
    required this.batchCount,
    required this.sectionCount,
    required this.studentCount,
    required this.totalRecordedCount,
    required this.presentCount,
    this.overallPercentage,
  });

  factory HodDashboard.fromJson(Map<String, dynamic> json) {
    return HodDashboard(
      departmentName: json['departmentName'] as String? ?? '',
      departmentCode: json['departmentCode'] as String? ?? '',
      programCount: (json['programCount'] as num?)?.toInt() ?? 0,
      batchCount: (json['batchCount'] as num?)?.toInt() ?? 0,
      sectionCount: (json['sectionCount'] as num?)?.toInt() ?? 0,
      studentCount: (json['studentCount'] as num?)?.toInt() ?? 0,
      totalRecordedCount: (json['totalRecordedCount'] as num?)?.toInt() ?? 0,
      presentCount: (json['presentCount'] as num?)?.toInt() ?? 0,
      overallPercentage: (json['overallPercentage'] as num?)?.toDouble(),
    );
  }
}